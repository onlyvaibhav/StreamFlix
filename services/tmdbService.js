const axios = require('axios');

const TMDB_API_KEY = process.env.TMDB_API_KEY;
const BASE_URL = 'https://api.themoviedb.org/3';

// Rate Limiting Helpers
const wait = (ms) => new Promise(resolve => setTimeout(resolve, ms));

const axiosInstance = axios.create({
    baseURL: BASE_URL,
    params: {
        api_key: TMDB_API_KEY,
    }
});

// Retry logic wrapper
async function fetchTMDB(endpoint, params = {}, retries = 3) {
    if (!TMDB_API_KEY) {
        console.warn('⚠️ TMDB_API_KEY is missing.');
        return null;
    }

    try {
        const response = await axiosInstance.get(endpoint, { params });
        return response.data;
    } catch (error) {
        if (retries > 0 && error.response && error.response.status === 429) {
            const retryAfter = error.response.headers['retry-after'] || 1;
            console.warn(`⏳ TMDB Rate Limit. Retrying in ${retryAfter}s...`);
            await wait(retryAfter * 1000);
            return fetchTMDB(endpoint, params, retries - 1);
        }
        console.error(`❌ TMDB Error [${endpoint}]:`, error.message);
        return null;
    }
}

// ========== PUBLIC API ==========

// Search
exports.searchMovie = async (query, year) => {
    const params = { query };
    if (year) params.primary_release_year = year;
    return await fetchTMDB('/search/movie', params);
};

exports.searchTV = async (query, year) => {
    const params = { query };
    if (year) params.first_air_date_year = year;
    return await fetchTMDB('/search/tv', params);
};

// Details
exports.getMovieDetails = async (id) => {
    return await fetchTMDB(`/movie/${id}`);
};

exports.getTVDetails = async (id) => {
    return await fetchTMDB(`/tv/${id}`);
};

exports.getSeasonDetails = async (tvId, seasonNumber) => {
    return await fetchTMDB(`/tv/${tvId}/season/${seasonNumber}`);
};

exports.getEpisodeDetails = async (tvId, seasonNumber, episodeNumber) => {
    return await fetchTMDB(`/tv/${tvId}/season/${seasonNumber}/episode/${episodeNumber}`);
};

// Discover / Lists
exports.getTrending = async (type = 'movie', timeWindow = 'week') => {
    return await fetchTMDB(`/trending/${type}/${timeWindow}`);
};

exports.getTopRated = async (type = 'movie') => {
    return await fetchTMDB(`/${type}/top_rated`);
};

exports.getPopular = async (type = 'movie') => {
    return await fetchTMDB(`/${type}/popular`);
};

exports.getByGenre = async (type = 'movie', genreId, page = 1) => {
    return await fetchTMDB(`/discover/${type}`, {
        with_genres: genreId,
        page
    });
};

exports.getGenres = async (type = 'movie') => {
    return await fetchTMDB(`/genre/${type}/list`);
};
