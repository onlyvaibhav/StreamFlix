const { Api } = require('telegram');
const { LRUCache } = require('lru-cache');
const bigInt = require('big-integer');

// Cache for parsed subtitles
const subtitleCache = new LRUCache({
    max: 200,
    ttl: 1000 * 60 * 60, // 1 hour
});

// ==================== SRT TO VTT CONVERTER ====================

function srtToVtt(srtContent) {
    // Clean BOM and normalize line endings
    let content = srtContent
        .replace(/^\uFEFF/, '')
        .replace(/\r\n/g, '\n')
        .replace(/\r/g, '\n')
        .trim();

    // Convert SRT timestamps to VTT format (comma → dot)
    content = content.replace(
        /(\d{2}:\d{2}:\d{2}),(\d{3})/g,
        '$1.$2'
    );

    return 'WEBVTT\n\n' + content;
}

// ==================== ASS/SSA TO VTT CONVERTER ====================

function assToVtt(assContent) {
    const lines = assContent.split(/\r?\n/);
    let vtt = 'WEBVTT\n\n';
    let count = 1;

    for (const line of lines) {
        // Match Dialogue lines
        // Format: Dialogue: Layer,Start,End,Style,Name,MarginL,MarginR,MarginV,Effect,Text
        const match = line.match(
            /^Dialogue:\s*\d+,(\d+:\d{2}:\d{2}\.\d{2}),(\d+:\d{2}:\d{2}\.\d{2}),([^,]*),([^,]*),\d+,\d+,\d+,([^,]*),(.*)/
        );

        if (match) {
            let [, startTime, endTime, , , , text] = match;

            // Convert ASS time (H:MM:SS.CC) to VTT (HH:MM:SS.MMM)
            startTime = convertAssTime(startTime);
            endTime = convertAssTime(endTime);

            // Clean ASS formatting tags
            text = text
                .replace(/\{\\[^}]*\}/g, '') // Remove {\tags}
                .replace(/\\N/g, '\n')        // Line breaks
                .replace(/\\n/g, '\n')
                .replace(/\\h/g, ' ')
                .trim();

            if (text) {
                vtt += `${count}\n${startTime} --> ${endTime}\n${text}\n\n`;
                count++;
            }
        }
    }

    return vtt;
}

function convertAssTime(assTime) {
    // Input:  H:MM:SS.CC  (centiseconds)
    // Output: HH:MM:SS.MMM
    const parts = assTime.split(/[:.]/);
    const h = parts[0].padStart(2, '0');
    const m = parts[1].padStart(2, '0');
    const s = parts[2].padStart(2, '0');
    const cs = parts[3] || '00';
    const ms = (parseInt(cs) * 10).toString().padStart(3, '0');
    return `${h}:${m}:${s}.${ms}`;
}

// ==================== DETECT & CONVERT ====================

function detectAndConvert(content, fileName) {
    const ext = fileName.toLowerCase().split('.').pop();
    const textContent = typeof content === 'string'
        ? content
        : content.toString('utf-8');

    // Already VTT
    if (ext === 'vtt' || textContent.trim().startsWith('WEBVTT')) {
        return textContent;
    }

    // SRT format
    if (ext === 'srt' || /^\d+\s*\n\d{2}:\d{2}:\d{2},\d{3}/m.test(textContent)) {
        return srtToVtt(textContent);
    }

    // ASS/SSA format
    if (ext === 'ass' || ext === 'ssa' || textContent.includes('[Script Info]')) {
        return assToVtt(textContent);
    }

    // Try SRT as default
    return srtToVtt(textContent);
}

// ==================== EXTRACT SUBTITLE LANGUAGE ====================

function extractSubtitleInfo(fileName, message) {
    const name = fileName.toLowerCase();
    const text = (message || '').toLowerCase();

    // Common language patterns
    const langPatterns = [
        { pattern: /\b(english|eng)\b/i, code: 'en', label: 'English' },
        { pattern: /\b(hindi|hin)\b/i, code: 'hi', label: 'Hindi' },
        { pattern: /\b(spanish|spa|esp)\b/i, code: 'es', label: 'Spanish' },
        { pattern: /\b(french|fra|fre)\b/i, code: 'fr', label: 'French' },
        { pattern: /\b(german|ger|deu)\b/i, code: 'de', label: 'German' },
        { pattern: /\b(japanese|jpn|jap)\b/i, code: 'ja', label: 'Japanese' },
        { pattern: /\b(korean|kor)\b/i, code: 'ko', label: 'Korean' },
        { pattern: /\b(chinese|chi|zho)\b/i, code: 'zh', label: 'Chinese' },
        { pattern: /\b(arabic|ara)\b/i, code: 'ar', label: 'Arabic' },
        { pattern: /\b(portuguese|por)\b/i, code: 'pt', label: 'Portuguese' },
        { pattern: /\b(italian|ita)\b/i, code: 'it', label: 'Italian' },
        { pattern: /\b(russian|rus)\b/i, code: 'ru', label: 'Russian' },
        { pattern: /\b(turkish|tur)\b/i, code: 'tr', label: 'Turkish' },
        { pattern: /\b(indonesian|ind)\b/i, code: 'id', label: 'Indonesian' },
        { pattern: /\b(malay|msa)\b/i, code: 'ms', label: 'Malay' },
        { pattern: /\b(tamil|tam)\b/i, code: 'ta', label: 'Tamil' },
        { pattern: /\b(telugu|tel)\b/i, code: 'te', label: 'Telugu' },
        { pattern: /\b(bengali|ben)\b/i, code: 'bn', label: 'Bengali' },
        { pattern: /\b(urdu|urd)\b/i, code: 'ur', label: 'Urdu' },
    ];

    const combined = name + ' ' + text;

    for (const { pattern, code, label } of langPatterns) {
        if (pattern.test(combined)) {
            return { code, label };
        }
    }

    return { code: 'un', label: 'Unknown' };
}

module.exports = {
    subtitleCache,
    srtToVtt,
    assToVtt,
    detectAndConvert,
    extractSubtitleInfo,
};