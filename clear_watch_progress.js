require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

async function run() {
  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY;

  if (!supabaseUrl || !supabaseKey) {
    console.error('Missing Supabase credentials in .env');
    return;
  }

  const supabase = createClient(supabaseUrl, supabaseKey);

  console.log('Clearing watch_progress table...');
  const { data, error } = await supabase
    .from('watch_progress')
    .delete()
    .neq('id', '00000000-0000-0000-0000-000000000000'); // Deletes all rows

  if (error) {
    console.error('Error clearing table:', error.message);
  } else {
    console.log('Successfully cleared watch_progress table.');
  }
}

run();
