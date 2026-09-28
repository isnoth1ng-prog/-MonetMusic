const express = require('express');
const { exec } = require('child_process');
const https = require('https');

const app = express();
const PORT = 3000;

app.get('/stream', (req, res) => {
    const query = req.query.q;
    if (!query) {
        return res.status(400).send('No query provided');
    }
    
    console.log(`Searching YouTube for: ${query}`);
    
    const command = `yt-dlp -f bestaudio -g "ytsearch1:${query.replace(/"/g, '')}"`;
    
    exec(command, (error, stdout, stderr) => {
        if (error) {
            console.error(`Error executing yt-dlp: ${error.message}`);
            return res.status(500).send('Failed to extract audio URL');
        }
        
        const streamUrl = stdout.trim();
        if (streamUrl) {
            console.log(`Proxying audio stream for: ${query}`);
            
            const options = {
                headers: {
                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
                }
            };
            
            // Pass along Range headers for seeking and buffering support
            if (req.headers.range) {
                options.headers['Range'] = req.headers.range;
            }
            
            https.get(streamUrl, options, (ytRes) => {
                // Copy all headers from YouTube to the client
                res.writeHead(ytRes.statusCode, ytRes.headers);
                ytRes.pipe(res);
            }).on('error', (err) => {
                console.error(`Proxy error: ${err.message}`);
                if (!res.headersSent) {
                    res.status(500).send('Proxy error');
                }
            });
            
        } else {
            res.status(404).send('No audio stream found');
        }
    });
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`MonetMusic Backend is running on port ${PORT}`);
    console.log(`Make sure yt-dlp is installed and available in your PATH.`);
});
