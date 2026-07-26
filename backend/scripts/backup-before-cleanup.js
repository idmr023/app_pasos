const { MongoClient } = require('mongodb');
const dns = require('dns');
const fs = require('fs');
const path = require('path');

dns.setServers(['8.8.8.8', '1.1.1.1']);

async function backup() {
  const client = new MongoClient(process.env.MONGODB_URI);
  await client.connect();
  
  const db = client.db();
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const backupDir = path.join(__dirname, '..', 'backups', `backup-${timestamp}`);
  
  fs.mkdirSync(backupDir, { recursive: true });
  
  const collections = await db.listCollections().toArray();
  
  for (const col of collections) {
    const data = await db.collection(col.name).find({}).toArray();
    fs.writeFileSync(
      path.join(backupDir, `${col.name}.json`),
      JSON.stringify(data, null, 2)
    );
    console.log(`✓ ${col.name}: ${data.length} documents`);
  }
  
  console.log(`\nBackup saved to: ${backupDir}`);
  await client.close();
}

require('dotenv').config();
backup().catch(console.error);
