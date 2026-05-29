const express = require('express');
const { config } = require('./db');
const routes = require('./routes');

const app = express();
app.use(express.json());
app.use(express.urlencoded({ extended: true })); 

app.get('/', (req, res) => {
    res.setHeader('Content-Type', 'text/html');
    res.send(`
        <h1>mywebapp - Task Tracker</h1>
        <ul>
            <li><a href="/tasks">GET /tasks</a> - List of all tasks</li>
            <li>POST /tasks - Create a new task (requires body: title)</li>
            <li>POST /tasks/&lt;id&gt;/done - Change task status to done</li>
        </ul>
    `);
});

app.use('/', routes);

const port = config.port || 8000;
const host = config.host || '0.0.0.0';

const server = app.listen(port, host, () => {
    console.log(`Started on ${host}:${port}`);
});

server.on('error', (err) => {
    console.error('Server error:', err);
});