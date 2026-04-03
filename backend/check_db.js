const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const db = new sqlite3.Database(path.join(__dirname, 'db', 'annadanam.sqlite'));

db.serialize(() => {
  db.all("SELECT name FROM sqlite_master WHERE type='table'", (err, tables) => {
    if (err) return console.error(err);
    console.log("Tables:");
    tables.forEach(t => console.log(' - ' + t.name));
    
    // Check donations and users
    db.all("SELECT * FROM users", (err, users) => {
      console.log("\\nUsers count:", users ? users.length : 0);
      if (users && users.length) console.log(users[0].name, users[0].email);
    });
    db.all("SELECT * FROM donations", (err, dons) => {
      console.log("\\nDonations count:", dons ? dons.length : 0);
    });
  });
});
setTimeout(()=>db.close(), 1000);
