const fs = require('fs');
const path = require('path');

const METADATA_DIR = path.join(__dirname, '../data/metadata');

const allItems = [];
const files = fs.readdirSync(METADATA_DIR);

for (const file of files) {
    if (!file.endsWith('.json')) continue;
    try {
        const data = JSON.parse(fs.readFileSync(path.join(METADATA_DIR, file), 'utf-8'));
        // Build concise item presentation
        const item = {
            id: data.fileId || data.tmdbId,
            title: data.title || data.fileName,
            thumbnail: data.backdrop || data.poster || null,
            genre: data.genres || [],
            rating: data.rating || 0,
            duration: data.runtime || (data.tv && data.tv.episodeRuntime) || 0,
            year: data.year || 0,
            description: (data.overview && data.overview.substring(0, 150) + '...') || '',
            popularity: data.popularity || 0,
            awards: data.awards || '',
            originalTitle: data.originalTitle || '',
            type: data.type || 'movie',
            certification: data.certification || ''
        };
        allItems.push(item);
    } catch (e) {
        // Skip
    }
}

// Helper functions for filtering and sorting
const sortPop = (a, b) => b.popularity - a.popularity;
const sortRat = (a, b) => b.rating - a.rating;
const sortYear = (a, b) => b.year - a.year;

const familyFriendlyRatings = ['G', 'PG', 'TV-G', 'TV-Y', 'TV-Y7', 'TV-PG', 'U', 'U/A 7+', 'U/A 13+', 'UA'];
const isFamilyFriendly = (i) => !i.certification || familyFriendlyRatings.includes(i.certification.toUpperCase());

// De-duplication tracking
const appCount = {};
const take = (list, count) => {
    const result = [];
    for (const item of list) {
        if (result.length >= count) break;
        if ((appCount[item.id] || 0) < 3) {
            result.push(item);
            appCount[item.id] = (appCount[item.id] || 0) + 1;
        }
    }
    return result;
};

// Start building output
const output = {
    homepage: {},
    category_pages: {},
    special_sections: {}
};

// ==== HOMEPAGE ====
// Hero Section: Top tier content, highly rated, popular
output.homepage.hero_section = take([...allItems].sort(sortPop).filter(i => i.rating > 7), 5); // 5-8

// Trending Now
output.homepage.trending_now = take([...allItems].sort(sortPop), 15);

// New Releases (Last 30 days - simulated by newest year and popularity)
output.homepage.new_releases = take([...allItems].sort(sortYear), 15);

// Top Rated
output.homepage.top_rated = take([...allItems].sort(sortRat), 15);

// Genre rows
output.homepage.genre_rows = {};
const genres = ['Action', 'Comedy', 'Drama', 'Horror', 'Romance', 'Science Fiction', 'Documentary', 'Animation', 'Crime', 'Family'];
for (const g of genres) {
    let filtered = allItems.filter(i => i.genre.includes(g) || i.genre.includes(g.replace('Science Fiction', 'Sci-Fi')));
    if (g === 'Family') {
        filtered = filtered.filter(isFamilyFriendly);
    }
    if (filtered.length > 0) {
        output.homepage.genre_rows[g.toLowerCase()] = take(filtered.sort(sortPop), 10);
    }
}

// Quick Picks (< 90m)
output.homepage.quick_picks = take([...allItems].filter(i => i.duration > 0 && i.duration < 90).sort(sortPop), 10);

// Award Winners
output.homepage.award_winners = take([...allItems].filter(i => i.awards || (i.rating > 7.5 && i.popularity > 150)).sort(sortPop), 10);

// Regional / Language Collections
output.homepage.regional_collections = {
    hollywood: take([...allItems].filter(i => (i.language === 'en' || !i.originalTitle.match(/[^\x00-\x7F]/))).sort(sortPop), 10),
    bollywood: take([...allItems].filter(i => i.originalTitle && i.originalTitle.match(/[\u0900-\u097F]/)).sort(sortPop), 10),
    kdrama: take([...allItems].filter(i => i.originalTitle && i.originalTitle.match(/[\uAC00-\uD7AF]/)).sort(sortPop), 10),
    anime: take([...allItems].filter(i => i.originalTitle && i.originalTitle.match(/[\u3040-\u30FF\u4E00-\u9FFF]/) && i.genre.includes('Animation')).sort(sortPop), 10)
};


// ==== CATEGORY PAGES ====
for (const g of genres) {
    let genreItems = allItems.filter(i => i.genre.includes(g) || i.genre.includes(g.replace('Science Fiction', 'Sci-Fi')));
    if (g === 'Family') {
        genreItems = genreItems.filter(isFamilyFriendly);
    }
    
    if (genreItems.length > 0) {
        output.category_pages[g.toLowerCase()] = {
            popular: take([...genreItems].sort(sortPop), 10),
            critically_acclaimed: take([...genreItems].sort(sortRat), 10),
            new: take([...genreItems].sort(sortYear), 10),
            hidden_gems: take([...genreItems].filter(i => i.popularity < 50 && i.rating > 7).sort(sortRat), 10),
            classic: take([...genreItems].filter(i => i.year < 2010).sort(sortPop), 10)
        };
    }
}

// ==== SPECIAL SECTIONS ====
output.special_sections.mood_based = {
    feel_good: take([...allItems].filter(i => i.genre.includes('Comedy') || i.genre.includes('Family')).sort(sortPop), 10),
    mind_bending: take([...allItems].filter(i => i.genre.includes('Mystery') || i.genre.includes('Science Fiction') || i.genre.includes('Thriller')).sort(sortRat), 10),
    laugh_out_loud: take([...allItems].filter(i => i.genre.includes('Comedy')).sort(sortPop), 10),
    tearjerkers: take([...allItems].filter(i => i.genre.includes('Drama') || i.genre.includes('Romance')).sort(sortRat), 10)
};

output.special_sections.occasion_based = {
    weekend_binge: take([...allItems].filter(i => i.type === 'tv').sort(sortPop), 10),
    date_night: take([...allItems].filter(i => i.genre.includes('Romance') || i.genre.includes('Comedy')).sort(sortPop), 10),
    family_movie_night: take([...allItems].filter(i => i.genre.includes('Family') || i.genre.includes('Animation')).filter(isFamilyFriendly).sort(sortPop), 10)
};

output.special_sections.duration_based = {
    quick_watches: take([...allItems].filter(i => i.duration > 0 && i.duration < 90).sort(sortPop), 10),
    epic_movies: take([...allItems].filter(i => i.duration > 150).sort(sortRat), 10),
    limited_series: take([...allItems].filter(i => i.type === 'tv').sort(sortPop), 10)
};

output.special_sections.decade_collections = {
    classics_90s: take([...allItems].filter(i => i.year >= 1990 && i.year < 2000).sort(sortPop), 10),
    favorites_2000s: take([...allItems].filter(i => i.year >= 2000 && i.year < 2010).sort(sortPop), 10),
    modern_masterpieces: take([...allItems].filter(i => i.year >= 2010).sort(sortRat), 10)
};

fs.writeFileSync(path.join(__dirname, '../curated_content.json'), JSON.stringify(output, null, 2));
console.log('Successfully generated curated_content.json');
