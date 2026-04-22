const { initTelegram, getDocument, detectAllTracks } = require('../services/telegramService');
const path = require('path');

async function testProbe(fileId) {
    console.log(`Starting test probe for ${fileId}...`);
    try {
        await initTelegram();
        const doc = await getDocument(fileId);
        if (!doc) {
            console.error('Document not found');
            return;
        }
        
        console.log(`File size: ${(Number(doc.size) / (1024 * 1024)).toFixed(2)} MB`);
        
        const result = await detectAllTracks(doc, fileId);
        console.log('Probe Result:', JSON.stringify(result, null, 2));
    } catch (error) {
        console.error('Probe Error:', error);
    } finally {
        process.exit(0);
    }
}

testProbe('540');
