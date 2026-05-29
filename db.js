const { Pool } = require('pg');
const fs = require('fs');

const configPath = process.env.NODE_ENV === 'production' 
  ? '/etc/mywebapp/config.json' 
  : './config.json';

const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));

const pool = new Pool(config.db);

module.exports = { pool, config };