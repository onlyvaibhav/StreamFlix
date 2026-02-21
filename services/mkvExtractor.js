// backend/services/mkvExtractor.js

// ==================== EBML/MKV CONSTANTS ====================

const SUBTITLE_CODECS = {
    'S_TEXT/UTF8': 'srt',
    'S_TEXT/SSA': 'ssa',
    'S_TEXT/ASS': 'ass',
    'S_TEXT/WEBVTT': 'vtt',
    'S_VOBSUB': 'vobsub',
    'S_HDMV/PGS': 'pgs',
    'S_DVBSUB': 'dvbsub',
};

const TEXT_SUBTITLE_CODECS = [
    'S_TEXT/UTF8',
    'S_TEXT/SSA',
    'S_TEXT/ASS',
    'S_TEXT/WEBVTT',
];

// EBML Element IDs we care about
const ELEMENT_IDS = {
    EBML: Buffer.from([0x1A, 0x45, 0xDF, 0xA3]),
    Segment: Buffer.from([0x18, 0x53, 0x80, 0x67]),
    Tracks: Buffer.from([0x16, 0x54, 0xAE, 0x6B]),
    TrackEntry: Buffer.from([0xAE]),
    TrackNumber: Buffer.from([0xD7]),
    TrackType: Buffer.from([0x83]),
    CodecID: Buffer.from([0x86]),
    Language: Buffer.from([0x22, 0xB5, 0x9C]),
    LanguageBCP47: Buffer.from([0x22, 0xB5, 0x9D]),
    Name: Buffer.from([0x53, 0x6E]),
    FlagDefault: Buffer.from([0x88]),
    FlagForced: Buffer.from([0x55, 0xAA]),
    CodecPrivate: Buffer.from([0x63, 0xA2]),
    Cluster: Buffer.from([0x1F, 0x43, 0xB6, 0x75]),
    Timestamp: Buffer.from([0xE7]),
    SimpleBlock: Buffer.from([0xA3]),
    BlockGroup: Buffer.from([0xA0]),
    Block: Buffer.from([0xA1]),
    BlockDuration: Buffer.from([0x9B]),
};

const TRACK_TYPE_SUBTITLE = 0x11; // 17

// ==================== EBML READER ====================

class EBMLReader {
    constructor(buffer) {
        this.buffer = buffer;
        this.pos = 0;
    }

    get remaining() {
        return this.buffer.length - this.pos;
    }

    get eof() {
        return this.pos >= this.buffer.length;
    }

    // Read EBML Variable-Size Integer (VINT)
    readVINT() {
        if (this.pos >= this.buffer.length) return null;

        const firstByte = this.buffer[this.pos];
        if (firstByte === 0) return null;

        // Determine length from leading bits
        let length = 0;
        let mask = 0x80;
        while (length < 8 && !(firstByte & mask)) {
            length++;
            mask >>= 1;
        }
        length++; // Include the first byte

        if (this.pos + length > this.buffer.length) return null;

        // Read value (without the length-indicating bits)
        let value = firstByte & (mask - 1);
        for (let i = 1; i < length; i++) {
            value = value * 256 + this.buffer[this.pos + i];
        }

        this.pos += length;
        return { value, length };
    }

    // Read Element ID (similar to VINT but keeps leading bits)
    readElementID() {
        if (this.pos >= this.buffer.length) return null;

        const firstByte = this.buffer[this.pos];
        if (firstByte === 0) return null;

        let length;
        if (firstByte & 0x80) length = 1;
        else if (firstByte & 0x40) length = 2;
        else if (firstByte & 0x20) length = 3;
        else if (firstByte & 0x10) length = 4;
        else return null;

        if (this.pos + length > this.buffer.length) return null;

        const idBytes = this.buffer.subarray(this.pos, this.pos + length);
        this.pos += length;

        return { id: idBytes, length };
    }

    // Read data size VINT
    readDataSize() {
        return this.readVINT();
    }

    // Read unsigned int from buffer
    readUInt(size) {
        if (this.pos + size > this.buffer.length) return 0;
        let value = 0;
        for (let i = 0; i < size; i++) {
            value = value * 256 + this.buffer[this.pos + i];
        }
        this.pos += size;
        return value;
    }

    // Read string
    readString(size) {
        if (this.pos + size > this.buffer.length) return '';
        const str = this.buffer.toString('utf-8', this.pos, this.pos + size);
        this.pos += size;
        // Remove null bytes
        return str.replace(/\0/g, '').trim();
    }

    // Read raw bytes
    readBytes(size) {
        if (this.pos + size > this.buffer.length) {
            size = this.buffer.length - this.pos;
        }
        const bytes = this.buffer.subarray(this.pos, this.pos + size);
        this.pos += size;
        return bytes;
    }

    // Skip bytes
    skip(size) {
        this.pos = Math.min(this.pos + size, this.buffer.length);
    }

    // Check if ID matches
    idEquals(readId, targetId) {
        if (!readId || readId.length !== targetId.length) return false;
        for (let i = 0; i < readId.length; i++) {
            if (readId[i] !== targetId[i]) return false;
        }
        return true;
    }
}

// ==================== MKV SUBTITLE EXTRACTOR ====================

class MKVSubtitleExtractor {
    constructor() {
        this.subtitleTracks = [];
        this.allTracks = [];
    }

    /**
     * Parse MKV header to find subtitle tracks
     * Uses two methods: structured EBML parse + binary search fallback
     */
    parseHeader(buffer) {
        this.subtitleTracks = [];
        this.allTracks = [];

        console.log(`   🔧 Parsing MKV header (${buffer.length} bytes)...`);

        // Method 1: Try structured EBML parsing
        try {
            this._parseEBML(buffer);
        } catch (error) {
            console.log(`   ⚠️ EBML parse error: ${error.message}`);
        }

        // Method 2: Binary search fallback (always run to catch what Method 1 missed)
        if (this.subtitleTracks.length === 0) {
            console.log('   🔧 Trying binary search fallback...');
            this._binarySearch(buffer);
        }

        console.log(`   📊 All tracks found: ${this.allTracks.length}`);
        console.log(`   🔤 Subtitle tracks: ${this.subtitleTracks.length}`);

        for (const track of this.subtitleTracks) {
            console.log(
                `      Track #${track.trackNumber}: ${track.codecId} ` +
                `[${track.language}] "${track.name}" ` +
                `${track.isDefault ? '(default)' : ''}`
            );
        }

        return this.subtitleTracks;
    }

    // ==================== METHOD 1: EBML PARSING ====================

    _parseEBML(buffer) {
        const reader = new EBMLReader(buffer);

        // Read EBML header
        const ebmlId = reader.readElementID();
        if (!ebmlId || !reader.idEquals(ebmlId.id, ELEMENT_IDS.EBML)) {
            console.log('   ⚠️ Not a valid EBML file');
            return;
        }

        const ebmlSize = reader.readDataSize();
        if (!ebmlSize) return;

        // Skip EBML header content
        reader.skip(ebmlSize.value);

        // Read Segment
        const segId = reader.readElementID();
        if (!segId || !reader.idEquals(segId.id, ELEMENT_IDS.Segment)) {
            console.log('   ⚠️ No Segment element found');
            return;
        }

        reader.readDataSize(); // Segment size (usually very large)

        // Now parse Segment children to find Tracks element
        this._parseSegmentChildren(reader, buffer.length);
    }

    _parseSegmentChildren(reader, maxPos) {
        const endPos = Math.min(maxPos, reader.buffer.length);
        let foundTracks = false;

        while (reader.pos < endPos - 4 && !reader.eof) {
            const startPos = reader.pos;
            const elementId = reader.readElementID();
            if (!elementId) { reader.pos = startPos + 1; continue; }

            const dataSize = reader.readDataSize();
            if (!dataSize) { reader.pos = startPos + 1; continue; }

            const size = dataSize.value;

            // Check for Tracks element
            if (reader.idEquals(elementId.id, ELEMENT_IDS.Tracks)) {
                console.log(`   📍 Found Tracks element at offset ${startPos}, size ${size}`);
                this._parseTracks(reader, reader.pos + size);
                foundTracks = true;
                break; // We found tracks, no need to continue
            }

            // Check for Cluster - if we hit clusters, tracks section is done
            if (reader.idEquals(elementId.id, ELEMENT_IDS.Cluster)) {
                console.log(`   📍 Hit Cluster at offset ${startPos}, stopping header parse`);
                break;
            }

            // Skip this element's content
            if (size > 0 && size < reader.buffer.length) {
                reader.skip(size);
            } else {
                reader.pos = startPos + 1;
            }
        }

        if (!foundTracks) {
            console.log('   ⚠️ Tracks element not found via EBML parsing');
        }
    }

    _parseTracks(reader, endPos) {
        while (reader.pos < endPos - 2 && !reader.eof) {
            const startPos = reader.pos;
            const elementId = reader.readElementID();
            if (!elementId) { reader.pos = startPos + 1; continue; }

            const dataSize = reader.readDataSize();
            if (!dataSize) { reader.pos = startPos + 1; continue; }

            const size = dataSize.value;

            if (reader.idEquals(elementId.id, ELEMENT_IDS.TrackEntry)) {
                const trackEndPos = reader.pos + size;
                const track = this._parseTrackEntry(reader, trackEndPos);

                if (track) {
                    this.allTracks.push(track);

                    if (
                        track.type === TRACK_TYPE_SUBTITLE &&
                        TEXT_SUBTITLE_CODECS.includes(track.codecId)
                    ) {
                        this.subtitleTracks.push({
                            trackNumber: track.number,
                            trackUid: track.uid,
                            codecId: track.codecId,
                            format: SUBTITLE_CODECS[track.codecId] || 'unknown',
                            language: track.language || 'und',
                            name: track.name || '',
                            isDefault: track.isDefault,
                            isForced: track.isForced,
                            codecPrivate: track.codecPrivate,
                        });
                    }
                }

                reader.pos = trackEndPos;
            } else {
                if (size > 0 && size < reader.buffer.length) {
                    reader.skip(size);
                } else {
                    reader.pos = startPos + 1;
                }
            }
        }
    }

    _parseTrackEntry(reader, endPos) {
        const track = {
            number: 0,
            uid: 0,
            type: 0,
            codecId: '',
            language: 'und',
            name: '',
            isDefault: true, // MKV default for FlagDefault is 1
            isForced: false,
            codecPrivate: null,
        };

        while (reader.pos < endPos - 2) {
            const startPos = reader.pos;
            const elementId = reader.readElementID();
            if (!elementId) { reader.pos = startPos + 1; continue; }

            const dataSize = reader.readDataSize();
            if (!dataSize) { reader.pos = startPos + 1; continue; }

            const size = dataSize.value;

            if (size > 10000000 || size < 0) {
                reader.pos = startPos + 1;
                continue;
            }

            if (reader.idEquals(elementId.id, ELEMENT_IDS.TrackNumber)) {
                track.number = reader.readUInt(size);
            } else if (reader.idEquals(elementId.id, ELEMENT_IDS.TrackType)) {
                track.type = reader.readUInt(size);
            } else if (reader.idEquals(elementId.id, ELEMENT_IDS.CodecID)) {
                track.codecId = reader.readString(size);
            } else if (reader.idEquals(elementId.id, ELEMENT_IDS.Language)) {
                track.language = reader.readString(size);
            } else if (reader.idEquals(elementId.id, ELEMENT_IDS.LanguageBCP47)) {
                track.language = reader.readString(size);
            } else if (reader.idEquals(elementId.id, ELEMENT_IDS.Name)) {
                track.name = reader.readString(size);
            } else if (reader.idEquals(elementId.id, ELEMENT_IDS.FlagDefault)) {
                track.isDefault = reader.readUInt(size) === 1;
            } else if (reader.idEquals(elementId.id, ELEMENT_IDS.FlagForced)) {
                track.isForced = reader.readUInt(size) === 1;
            } else if (reader.idEquals(elementId.id, ELEMENT_IDS.CodecPrivate)) {
                track.codecPrivate = reader.readBytes(size);
            } else {
                reader.skip(size);
            }
        }

        if (track.type > 0 && track.codecId) {
            return track;
        }
        return null;
    }

    // ==================== METHOD 2: BINARY SEARCH ====================

    _binarySearch(buffer) {
        console.log('   🔎 Searching for subtitle codec strings in binary data...');

        const searchStrings = TEXT_SUBTITLE_CODECS;
        const bufferStr = buffer.toString('binary');

        for (const codecId of searchStrings) {
            let searchFrom = 0;

            while (true) {
                const idx = bufferStr.indexOf(codecId, searchFrom);
                if (idx === -1) break;

                console.log(`   📍 Found "${codecId}" at byte offset ${idx}`);

                // Extract track info from surrounding bytes
                const track = this._extractTrackFromBinary(buffer, idx, codecId);

                if (track) {
                    // Avoid duplicates
                    const exists = this.subtitleTracks.find(
                        (t) => t.trackNumber === track.trackNumber && t.codecId === track.codecId
                    );

                    if (!exists) {
                        this.subtitleTracks.push(track);
                        this.allTracks.push({
                            number: track.trackNumber,
                            type: TRACK_TYPE_SUBTITLE,
                            codecId: track.codecId,
                        });
                    }
                }

                searchFrom = idx + codecId.length;
            }
        }
    }

    _extractTrackFromBinary(buffer, codecPos, codecId) {
        // Search region around the codec string
        const regionStart = Math.max(0, codecPos - 500);
        const regionEnd = Math.min(buffer.length, codecPos + 500);
        const region = buffer.subarray(regionStart, regionEnd);
        const offsetInRegion = codecPos - regionStart;

        let trackNumber = 0;
        let language = 'und';
        let name = '';
        let isDefault = false;

        // ── Find Track Number ──
        for (let i = Math.max(0, offsetInRegion - 200); i < offsetInRegion; i++) {
            if (region[i] === 0xd7) {
                const sizeInfo = this._readVINTFromBuffer(region, i + 1);
                if (sizeInfo && sizeInfo.value > 0 && sizeInfo.value <= 4) {
                    const numStart = i + 1 + sizeInfo.length;
                    if (numStart + sizeInfo.value <= region.length) {
                        let num = 0;
                        for (let j = 0; j < sizeInfo.value; j++) {
                            num = num * 256 + region[numStart + j];
                        }
                        if (num > 0 && num < 100) {
                            trackNumber = num;
                            break;
                        }
                    }
                }
            }
        }

        // ── Find Language ──
        for (let i = 0; i < region.length - 5; i++) {
            if (region[i] === 0x22 && region[i + 1] === 0xb5 && region[i + 2] === 0x9c) {
                const sizeInfo = this._readVINTFromBuffer(region, i + 3);
                if (sizeInfo && sizeInfo.value > 0 && sizeInfo.value <= 20) {
                    const strStart = i + 3 + sizeInfo.length;
                    if (strStart + sizeInfo.value <= region.length) {
                        const raw = region
                            .toString('utf-8', strStart, strStart + sizeInfo.value)
                            .replace(/\0/g, '')
                            .trim();

                        // Validate: language codes are short ASCII strings
                        if (raw.length >= 2 && raw.length <= 10 && /^[a-zA-Z-]+$/.test(raw)) {
                            language = raw;
                            break;
                        }
                    }
                }
            }
        }

        // ── Find Name ──
        for (let i = 0; i < region.length - 5; i++) {
            if (region[i] === 0x53 && region[i + 1] === 0x6e) {
                const sizeInfo = this._readVINTFromBuffer(region, i + 2);
                if (sizeInfo && sizeInfo.value > 0 && sizeInfo.value <= 200) {
                    const strStart = i + 2 + sizeInfo.length;
                    if (strStart + sizeInfo.value <= region.length) {
                        const raw = region
                            .toString('utf-8', strStart, strStart + sizeInfo.value)
                            .replace(/\0/g, '')
                            .trim();

                        // Validate: name should be printable text
                        if (raw.length > 0 && raw.length <= 100 && /^[\x20-\x7E\u00C0-\u024F\u0900-\u097F]+/.test(raw)) {
                            name = raw;
                            break;
                        }
                    }
                }
            }
        }

        // ── Find FlagDefault ──
        for (let i = 0; i < region.length - 3; i++) {
            if (region[i] === 0x88 && region[i + 1] === 0x81) {
                isDefault = region[i + 2] === 1;
                break;
            }
        }

        if (trackNumber === 0) {
            trackNumber = this.subtitleTracks.length + 1 + 100;
        }

        // Build clean label
        const langLabel = getLanguageLabel(language);
        const displayName = name || langLabel;

        console.log(
            `   ✅ Extracted: Track #${trackNumber}, ` +
            `Lang="${language}" (${langLabel}), Name="${name}", ` +
            `Codec="${codecId}", Default=${isDefault}`
        );

        return {
            trackNumber,
            trackUid: 0,
            codecId,
            format: SUBTITLE_CODECS[codecId] || 'srt',
            language,
            name: displayName,
            isDefault,
            isForced: false,
            codecPrivate: null,
        };
    }

    _readVINTFromBuffer(buffer, pos) {
        if (pos >= buffer.length) return null;

        const firstByte = buffer[pos];
        if (firstByte === 0) return null;

        let length = 0;
        let mask = 0x80;
        while (length < 8 && !(firstByte & mask)) {
            length++;
            mask >>= 1;
        }
        length++;

        if (pos + length > buffer.length) return null;

        let value = firstByte & (mask - 1);
        for (let i = 1; i < length; i++) {
            value = value * 256 + buffer[pos + i];
        }

        return { value, length };
    }

    // ==================== EXTRACT SUBTITLE DATA FROM CLUSTERS ====================

    extractSubtitleData(buffer, trackNumber) {
        console.log(`   🔎 Extracting subtitle blocks for track #${trackNumber}...`);

        const cues = [];
        let clusterTimestamp = 0;
        let clusterCount = 0;
        let pos = 0;

        while (pos < buffer.length - 8) {
            // Find Cluster element: 0x1F 0x43 0xB6 0x75
            if (
                buffer[pos] === 0x1f &&
                buffer[pos + 1] === 0x43 &&
                buffer[pos + 2] === 0xb6 &&
                buffer[pos + 3] === 0x75
            ) {
                clusterCount++;
                pos += 4;

                // Read cluster size
                const clusterSizeInfo = this._readVINTFromBuffer(buffer, pos);
                if (!clusterSizeInfo) { pos++; continue; }
                pos += clusterSizeInfo.length;

                const clusterEnd = Math.min(
                    pos + clusterSizeInfo.value,
                    buffer.length
                );

                // Parse cluster contents
                while (pos < clusterEnd - 2) {
                    // Timestamp (0xE7)
                    if (buffer[pos] === 0xe7) {
                        pos++;
                        const sizeInfo = this._readVINTFromBuffer(buffer, pos);
                        if (!sizeInfo) { pos++; continue; }
                        pos += sizeInfo.length;

                        clusterTimestamp = 0;
                        for (let i = 0; i < sizeInfo.value && pos + i < buffer.length; i++) {
                            clusterTimestamp = clusterTimestamp * 256 + buffer[pos + i];
                        }
                        pos += sizeInfo.value;
                        continue;
                    }

                    // SimpleBlock (0xA3)
                    if (buffer[pos] === 0xa3) {
                        pos++;
                        const blockSizeInfo = this._readVINTFromBuffer(buffer, pos);
                        if (!blockSizeInfo) { pos++; continue; }
                        pos += blockSizeInfo.length;

                        const blockEnd = pos + blockSizeInfo.value;
                        if (blockEnd > buffer.length) { pos = clusterEnd; break; }

                        // Read track number from block
                        const blockTrackInfo = this._readVINTFromBuffer(buffer, pos);
                        if (!blockTrackInfo) { pos = blockEnd; continue; }

                        const blockTrack = blockTrackInfo.value;
                        pos += blockTrackInfo.length;

                        if (blockTrack === trackNumber && pos + 3 <= blockEnd) {
                            // Read timestamp offset (2 bytes signed)
                            const tsOffset = buffer.readInt16BE(pos);
                            pos += 2;

                            // Skip flags (1 byte)
                            pos++;

                            // Read subtitle text
                            const dataLen = blockEnd - pos;
                            if (dataLen > 0 && dataLen < 100000) {
                                const text = buffer.toString('utf-8', pos, blockEnd).trim();
                                if (text.length > 0) {
                                    cues.push({
                                        startTime: clusterTimestamp + tsOffset,
                                        text,
                                    });
                                }
                            }
                        }

                        pos = blockEnd;
                        continue;
                    }

                    // BlockGroup (0xA0)
                    if (buffer[pos] === 0xa0) {
                        pos++;
                        const bgSizeInfo = this._readVINTFromBuffer(buffer, pos);
                        if (!bgSizeInfo) { pos++; continue; }
                        pos += bgSizeInfo.length;

                        const bgEnd = pos + bgSizeInfo.value;
                        if (bgEnd > buffer.length) { pos = clusterEnd; break; }

                        let blockData = null;
                        let blockTimestamp = 0;
                        let blockDuration = 0;
                        let blockTrackNum = 0;

                        // Parse BlockGroup contents
                        while (pos < bgEnd - 2) {
                            // Block (0xA1)
                            if (buffer[pos] === 0xa1) {
                                pos++;
                                const bSizeInfo = this._readVINTFromBuffer(buffer, pos);
                                if (!bSizeInfo) { pos++; continue; }
                                pos += bSizeInfo.length;

                                const bEnd = pos + bSizeInfo.value;

                                const btInfo = this._readVINTFromBuffer(buffer, pos);
                                if (!btInfo) { pos = bEnd; continue; }

                                blockTrackNum = btInfo.value;
                                pos += btInfo.length;

                                if (blockTrackNum === trackNumber && pos + 3 <= bEnd) {
                                    blockTimestamp = buffer.readInt16BE(pos);
                                    pos += 2;
                                    pos++; // flags

                                    const dLen = bEnd - pos;
                                    if (dLen > 0 && dLen < 100000) {
                                        blockData = buffer.toString('utf-8', pos, bEnd).trim();
                                    }
                                }

                                pos = bEnd;
                                continue;
                            }

                            // BlockDuration (0x9B)
                            if (buffer[pos] === 0x9b) {
                                pos++;
                                const dSizeInfo = this._readVINTFromBuffer(buffer, pos);
                                if (!dSizeInfo) { pos++; continue; }
                                pos += dSizeInfo.length;

                                blockDuration = 0;
                                for (let i = 0; i < dSizeInfo.value && pos + i < buffer.length; i++) {
                                    blockDuration = blockDuration * 256 + buffer[pos + i];
                                }
                                pos += dSizeInfo.value;
                                continue;
                            }

                            // Skip unknown elements
                            pos++;
                        }

                        if (blockData && blockTrackNum === trackNumber) {
                            cues.push({
                                startTime: clusterTimestamp + blockTimestamp,
                                duration: blockDuration,
                                text: blockData,
                            });
                        }

                        pos = bgEnd;
                        continue;
                    }

                    pos++;
                }

                // Log progress periodically
                if (clusterCount % 500 === 0) {
                    console.log(
                        `   📊 Processed ${clusterCount} clusters, ${cues.length} cues found...`
                    );
                }

                continue;
            }

            pos++;
        }

        console.log(
            `   📊 Processed ${clusterCount} clusters total, extracted ${cues.length} subtitle cues`
        );

        return cues;
    }
}

// ==================== LANGUAGE HELPERS ====================

function getLanguageLabel(code) {
    const languages = {
        eng: 'English', en: 'English',
        hin: 'Hindi', hi: 'Hindi',
        spa: 'Spanish', es: 'Spanish',
        fre: 'French', fra: 'French', fr: 'French',
        ger: 'German', deu: 'German', de: 'German',
        jpn: 'Japanese', ja: 'Japanese',
        kor: 'Korean', ko: 'Korean',
        chi: 'Chinese', zho: 'Chinese', zh: 'Chinese',
        ara: 'Arabic', ar: 'Arabic',
        por: 'Portuguese', pt: 'Portuguese',
        ita: 'Italian', it: 'Italian',
        rus: 'Russian', ru: 'Russian',
        tur: 'Turkish', tr: 'Turkish',
        tam: 'Tamil', ta: 'Tamil',
        tel: 'Telugu', te: 'Telugu',
        ben: 'Bengali', bn: 'Bengali',
        urd: 'Urdu', ur: 'Urdu',
        und: 'Unknown', mul: 'Multiple',
    };
    return languages[code] || code || 'Unknown';
}

// ==================== CONVERT CUES TO VTT ====================

function cuesToVTT(cues, codecId, codecPrivate) {
    if (codecId === 'S_TEXT/ASS' || codecId === 'S_TEXT/SSA') {
        return assDataToVTT(cues, codecPrivate);
    }

    let vtt = 'WEBVTT\n\n';
    cues.sort((a, b) => a.startTime - b.startTime);

    for (let i = 0; i < cues.length; i++) {
        const cue = cues[i];
        const start = formatVTTTime(cue.startTime);

        let endTime;
        if (cue.duration && cue.duration > 0) {
            endTime = cue.startTime + cue.duration;
        } else if (i + 1 < cues.length) {
            endTime = Math.min(cues[i + 1].startTime, cue.startTime + 10000);
        } else {
            endTime = cue.startTime + 5000;
        }

        const end = formatVTTTime(endTime);
        const text = cleanSubtitleText(cue.text);

        if (text) {
            vtt += `${i + 1}\n${start} --> ${end}\n${text}\n\n`;
        }
    }

    return vtt;
}

function assDataToVTT(cues, codecPrivate) {
    let vtt = 'WEBVTT\n\n';
    let count = 1;

    cues.sort((a, b) => a.startTime - b.startTime);

    for (const cue of cues) {
        let text = cue.text;

        // ASS block data: may contain ReadOrder,Layer,Style,Name,...,Text
        if (text.includes(',')) {
            const parts = text.split(',');
            if (parts.length >= 9) {
                text = parts.slice(8).join(',');
            }
        }

        text = text
            .replace(/\{\\[^}]*\}/g, '')
            .replace(/\\N/g, '\n')
            .replace(/\\n/g, '\n')
            .replace(/\\h/g, ' ')
            .trim();

        if (!text) continue;

        const start = formatVTTTime(cue.startTime);

        let endTime;
        if (cue.duration && cue.duration > 0) {
            endTime = cue.startTime + cue.duration;
        } else {
            endTime = cue.startTime + 5000;
        }
        const end = formatVTTTime(endTime);

        vtt += `${count}\n${start} --> ${end}\n${text}\n\n`;
        count++;
    }

    return vtt;
}

function formatVTTTime(ms) {
    if (ms < 0) ms = 0;
    const hours = Math.floor(ms / 3600000);
    const minutes = Math.floor((ms % 3600000) / 60000);
    const seconds = Math.floor((ms % 60000) / 1000);
    const millis = ms % 1000;

    return (
        hours.toString().padStart(2, '0') + ':' +
        minutes.toString().padStart(2, '0') + ':' +
        seconds.toString().padStart(2, '0') + '.' +
        millis.toString().padStart(3, '0')
    );
}

function cleanSubtitleText(text) {
    return text
        .replace(/<[^>]+>/g, '')
        .replace(/\{\\[^}]*\}/g, '')
        .replace(/\\N/g, '\n')
        .replace(/\\n/g, '\n')
        .trim();
}

module.exports = {
    MKVSubtitleExtractor,
    getLanguageLabel,
    cuesToVTT,
    TEXT_SUBTITLE_CODECS,
    SUBTITLE_CODECS,
};