const fs = require('fs').promises;
const path = require('path');
require('dotenv').config();
const TMDBClient = require('../services/tmdbClient');

const METADATA_DIR = path.join(__dirname, '../data/metadata');
const client = new TMDBClient(process.env.TMDB_API_KEY);

async function run() {
    console.log('🚀 Starting age certification update...');
    
    if (!process.env.TMDB_API_KEY) {
        console.error('❌ TMDB_API_KEY is missing in .env');
        process.exit(1);
    }

    let files;
    try {
        files = await fs.readdir(METADATA_DIR);
    } catch (err) {
        console.error(`❌ Could not read metadata directory: ${err.message}`);
        process.exit(1);
    }

    const jsonFiles = files.filter(f => f.endsWith('.json'));
    console.log(`📂 Found ${jsonFiles.length} metadata files.`);

    const cache = new Map(); // key: "type:tmdbId", value: certification
    let updatedCount = 0;
    let skippedCount = 0;
    let errorCount = 0;

    for (let i = 0; i < jsonFiles.length; i++) {
        const file = jsonFiles[i];
        const filePath = path.join(METADATA_DIR, file);

        try {
            const content = await fs.readFile(filePath, 'utf-8');
            const data = JSON.parse(content);

            if (!data.tmdbId || !data.type) {
                skippedCount++;
                continue;
            }

            // Check if certification already exists and is valid
            if (data.certification) {
                skippedCount++;
                continue;
            }

            const cacheKey = `${data.type}:${data.tmdbId}`;
            let certification;

            if (cache.has(cacheKey)) {
                certification = cache.get(cacheKey);
            } else {
                process.stdout.write(`🌐 Fetching certification for ${data.type} ${data.tmdbId} (${data.title})... `);
                certification = await client.fetchCertification(data.type, data.tmdbId);
                cache.set(cacheKey, certification);
                console.log(certification || 'N/A');
            }

            if (certification) {
                data.certification = certification;
                await fs.writeFile(filePath, JSON.stringify(data, null, 2));
                updatedCount++;
            } else {
                // Mark as N/A or just skip updating if you want to retry later
                // The user said "update json as well after fetching", so I'll set it to "N/A" if truly not found
                data.certification = 'N/A';
                await fs.writeFile(filePath, JSON.stringify(data, null, 2));
                updatedCount++;
            }

        } catch (err) {
            console.error(`\n❌ Error processing ${file}: ${err.message}`);
            errorCount++;
        }

        if ((i + 1) % 10 === 0 || i === jsonFiles.length - 1) {
            console.log(`📊 Progress: ${i+1}/${jsonFiles.length} files processed...`);
        }
    }

    console.log('\n✅ Update Complete!');
    console.log(`✨ Updated: ${updatedCount}`);
    console.log(`⏩ Skipped: ${skippedCount}`);
    console.log(`❌ Errors:  ${errorCount}`);
}

run();
