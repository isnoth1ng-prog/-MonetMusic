const express = require('express');
const { exec } = require('child_process');
const https = require('https');
const http = require('http');

const app = express();
const PORT = 3000;

app.get('/stream', (req, res) => {
    const query = req.query.q;
    if (!query) {
        return res.status(400).send('No query provided');
    }
    
    console.log(`\n[REQUEST] Streaming: ${query}`);
    
    const command = `yt-dlp -f bestaudio -g "ytsearch1:${query.replace(/"/g, '')}"`;
    
    exec(command, (error, stdout, stderr) => {
        if (error) {
            console.error(`[ERROR] yt-dlp failed: ${error.message}`);
            return res.status(500).send('Failed to extract audio URL');
        }
        
        const streamUrl = stdout.trim();
        if (!streamUrl) {
            return res.status(404).send('No audio stream found');
        }
        
        console.log(`[PROXY] Initial URL acquired. fetching...`);
        let currentProxyReq = null;
        
        function makeRequest(urlToFetch) {
            const options = {
                headers: {
                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                    'Accept': '*/*'
                }
            };
            
            if (req.headers.range) {
                options.headers['Range'] = req.headers.range;
                console.log(`[PROXY] Range requested: ${req.headers.range}`);
            }
            
            const reqClient = urlToFetch.startsWith('https') ? https : http;
            
            currentProxyReq = reqClient.get(urlToFetch, options, (ytRes) => {
                console.log(`[PROXY] YouTube responded with ${ytRes.statusCode}`);
                
                // Handle Redirects
                if (ytRes.statusCode >= 300 && ytRes.statusCode < 400 && ytRes.headers.location) {
                    console.log(`[PROXY] Following redirect...`);
                    return makeRequest(ytRes.headers.location);
                }
                
                // Remove headers that might cause issues for iOS
                delete ytRes.headers['strict-transport-security'];
                
                res.writeHead(ytRes.statusCode, ytRes.headers);
                ytRes.pipe(res);
                
                ytRes.on('error', (err) => {
                    console.error(`[ERROR] YouTube Stream Error: ${err.message}`);
                });
            });
            
            currentProxyReq.on('error', (err) => {
                console.error(`[ERROR] Proxy Request Error: ${err.message}`);
                if (!res.headersSent) {
                    res.status(500).send('Proxy error');
                }
            });
        }
        
        makeRequest(streamUrl);
        
        req.on('close', () => {
            console.log(`[CLIENT] Disconnected`);
            if (currentProxyReq) {
                currentProxyReq.destroy();
            }
        });
    });
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`========================================`);
    console.log(` MonetMusic Backend is running!`);
    console.log(` Port: ${PORT}`);
    console.log(` Proxy mode: ON (Handling redirects)`);
    console.log(`========================================`);
});
