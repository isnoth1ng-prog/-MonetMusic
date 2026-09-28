const express = require('express');
const { exec } = require('child_process');

const app = express();
const PORT = 3000;

app.get('/stream', (req, res) => {
    const query = req.query.q;
    if (!query) {
        return res.status(400).send('No query provided');
    }
    
    console.log(`Searching YouTube for: ${query}`);
    
    // Use yt-dlp to search and get the direct audio stream URL
    // -x: audio only
    // -g: get URL
    const command = `yt-dlp -f bestaudio -g "ytsearch1:${query.replace(/"/g, '')}"`;
    
    exec(command, (error, stdout, stderr) => {
        if (error) {
            console.error(`Error executing yt-dlp: ${error.message}`);
            return res.status(500).send('Failed to extract audio URL');
        }
        
        const streamUrl = stdout.trim();
        if (streamUrl) {
            console.log(`Redirecting to audio stream for: ${query}`);
            // Redirect the iOS AVPlayer directly to the YouTube audio stream
            res.redirect(302, streamUrl);
        } else {
            res.status(404).send('No audio stream found');
        }
    });
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`MonetMusic Backend is running on port ${PORT}`);
    console.log(`Make sure yt-dlp is installed and available in your PATH.`);
});
