const fs = require('fs');
const path = require('path');
const TMDBClient = require('./services/tmdbClient.js');

const DATA_DIR = path.join(__dirname, 'data', 'metadata');

async function run() {
  const tmdb = new TMDBClient(process.env.TMDB_API_KEY);
  const files = fs.readdirSync(DATA_DIR).filter(f => f.endsWith('.json'));

  const tvMap = new Map(); // TMDB ID -> list of files

  for (const f of files) {
    try {
      const data = JSON.parse(fs.readFileSync(path.join(DATA_DIR, f)));
      if (data.type === 'tv' || (data.tv && data.tv.showTmdbId)) {
        const id = data.tv?.showTmdbId || data.tmdbId;
        if (!tvMap.has(id)) tvMap.set(id, []);
        tvMap.get(id).push(f);
      }
    } catch (e) {
      // ignore parse errors
    }
  }

  console.log(`Found ${tvMap.size} unique TV shows across ${files.length} files.`);

  let updatedCount = 0;

  for (const [showId, episodes] of tvMap.entries()) {
    try {
      console.log(`Fetching TMDB /tv/${showId}...`);
      const d = await tmdb.request(`/tv/${showId}`);
      if (d.networks && d.networks.length > 0) {
        for (const file of episodes) {
          const fp = path.join(DATA_DIR, file);
          const meta = JSON.parse(fs.readFileSync(fp));
          if (!meta.productionCompanies) meta.productionCompanies = [];
          
          let modified = false;
          for (const net of d.networks) {
            if (!meta.productionCompanies.some(c => c.id === net.id)) {
              meta.productionCompanies.push({
                id: net.id,
                name: net.name,
                logoPath: net.logo_path
              });
              modified = true;
            }
          }
          if (modified) {
            fs.writeFileSync(fp, JSON.stringify(meta, null, 2));
            updatedCount++;
          }
        }
      }
      await new Promise(r => setTimeout(r, 100)); // sleep to avoid rate limiting
    } catch (e) {
      console.error(`Error processing show ${showId}:`, e.message);
    }
  }

  console.log(`Successfully updated ${updatedCount} episode files with network data.`);
}

run().catch(console.error);
