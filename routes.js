const express = require('express');
const { pool } = require('./db');

const router = express.Router();

function sendResponse(req, res, data, htmlTemplate) {
    if (req.accepts('html')) {
        res.setHeader('Content-Type', 'text/html');
        res.send(htmlTemplate);
    } else {
        res.json(data);
    }
}

router.get('/health/alive', (req, res) => {
    res.status(200).send('OK');
});

router.get('/health/ready', async (req, res) => {
    try {
        await pool.query('SELECT 1');
        res.status(200).send('OK');
    } catch (err) {
        res.status(500).send('Database connection error: ' + err.message);
    }
});

router.get('/tasks', async (req, res) => {
    try {
        const result = await pool.query('SELECT * FROM tasks ORDER BY created_at DESC');
        const tasks = result.rows;

        const html = `
            <h2>Task List</h2>
            <table border="1">
                <tr><th>ID</th><th>Title</th><th>Status</th><th>Created At</th></tr>
                ${tasks.map(t => `<tr><td>${t.id}</td><td>${t.title}</td><td>${t.status}</td><td>${t.created_at}</td></tr>`).join('')}
            </table>
        `;
        sendResponse(req, res, tasks, html);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

router.post('/tasks', async (req, res) => {
    const { title } = req.body;
    if (!title) return res.status(400).send('Title is required');

    try {
        const result = await pool.query(
            'INSERT INTO tasks (title) VALUES ($1) RETURNING *',
            [title]
        );
        const newTask = result.rows[0];
        sendResponse(req, res, newTask, `<p>Task created: ${newTask.title}</p>`);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

router.post('/tasks/:id/done', async (req, res) => {
    const { id } = req.params;
    try {
        const result = await pool.query(
            "UPDATE tasks SET status = 'done' WHERE id = $1 RETURNING *",
            [id]
        );
        if (result.rows.length === 0) return res.status(404).send('Task not found');
        
        const updatedTask = result.rows[0];
        sendResponse(req, res, updatedTask, `<p>Task ${id} is marked as done!</p>`);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

module.exports = router;