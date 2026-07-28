module.exports = [
  { id: 'new_releases', title: '🎬 New Releases', type: 'movie', params: { sort_by: 'primary_release_date.desc' } },
  { id: 'indian_cinema', title: '🇮🇳 Indian Cinema', type: 'movie', params: { with_origin_country: 'IN' } },
  { id: 'comedy', title: '🎭 Comedy', type: 'movie', params: { with_genres: '35' } },
  { id: 'sci_fi', title: '🚀 Sci-Fi', type: 'movie', params: { with_genres: '878' } },
  { id: 'horror', title: '😱 Horror', type: 'movie', params: { with_genres: '27' } },
  { id: 'romance', title: '❤️ Romance', type: 'movie', params: { with_genres: '10749' } },
  { id: 'family', title: '👨‍👩‍👧 Family', type: 'movie', params: { with_genres: '10751' } },
  { id: 'anime', title: '🇯🇵 Anime', type: 'tv', params: { with_genres: '16', with_origin_country: 'JP' } },
  { id: 'under_2_hours', title: '🍿 Movies Under 2 Hours', type: 'movie', params: { 'with_runtime.lte': 120 } },
  { id: 'award_winning', title: '🏆 Award-Winning', type: 'movie', params: { 'vote_average.gte': 8.5, 'vote_count.gte': 5000 } }
];
