const express = require('express');
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const app = express();
const PORT = 3000;

// Create cache directory
const CACHE_DIR = path.join(__dirname, 'cache');
if (!fs.existsSync(CACHE_DIR)) {
    fs.mkdirSync(CACHE_DIR);
}

// Serve static files from cache (handles Range requests automatically!)
app.use('/cache', express.static(CACHE_DIR));

app.get('/stream', (req, res) => {
    const query = req.query.q;
    if (!query) {
        return res.status(400).send('No query provided');
    }
    
    // Create a safe hash for the filename
    const hash = crypto.createHash('md5').update(query).digest('hex');
    const filename = `${hash}.m4a`;
    const filepath = path.join(CACHE_DIR, filename);
    const fileUrl = `/cache/${filename}`;
    
    // If we already downloaded this song, just redirect to it immediately!
    if (fs.existsSync(filepath)) {
        console.log(`[CACHE HIT] ${query} -> ${filename}`);
        return res.redirect(fileUrl);
    }
    
    const safeQuery = query.replace(/"/g, '') + " audio topic";
    const command = `yt-dlp -f "bestaudio[ext=m4a]" -o "${filepath}" "ytsearch1:${safeQuery}"`;
    
    exec(command, (error, stdout, stderr) => {
        if (error) {
            console.error(`[ERROR] yt-dlp failed: ${error.message}`);
            return res.status(500).send('Failed to download audio');
        }
        
        console.log(`[READY] Download complete for: ${query}`);
        
        // Redirect the iOS app to the static file which perfectly supports streaming and seeking
        res.redirect(fileUrl);
    });
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`========================================`);
    console.log(` MonetMusic Backend is running!`);
    console.log(` Port: ${PORT}`);
    console.log(` Mode: DOWNLOAD & CACHE (Bulletproof)`);
    console.log(`========================================`);
});
