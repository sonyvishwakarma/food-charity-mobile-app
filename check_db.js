const sqlite3 = require('sqlite3').verbose();
const db = new sqlite3.Database('./backend/db/annadanam.sqlite');

db.serialize(() => {
  db.all("SELECT name FROM sqlite_master WHERE type='table'", (err, tables) => {
    if (err) return console.error(err);
    console.log("Tables:");
    tables.forEach(t => console.log(' - ' + t.name));
    
    // Check donations and users
    db.all("SELECT * FROM users", (err, users) => {
      console.log("\\nUsers count:", users ? users.length : 0);
      if (users && users.length) console.log(users[0]);
    });
    db.all("SELECT * FROM donations", (err, dons) => {
      console.log("\\nDonations count:", dons ? dons.length : 0);
      if (dons && dons.length) console.log(dons[0]);
    });
  });
});
db.close();
