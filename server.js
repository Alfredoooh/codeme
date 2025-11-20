const express = require('express');
const cors = require('cors');
const fs = require('fs').promises;
const path = require('path');

const app = express();
app.use(cors());
app.use(express.json());

const DATA_FILE = path.join(__dirname, 'data.json');

async function ensureDataFile() {
  try {
    await fs.access(DATA_FILE);
  } catch (err) {
    // cria ficheiro com array vazio se não existir
    await fs.writeFile(DATA_FILE, JSON.stringify([], null, 2), 'utf8');
  }
}

async function readData() {
  await ensureDataFile();
  const content = await fs.readFile(DATA_FILE, 'utf8');
  return JSON.parse(content || '[]');
}

async function writeData(data) {
  await fs.writeFile(DATA_FILE, JSON.stringify(data, null, 2), 'utf8');
}

// Rota de status
app.get('/', (req, res) => {
  res.json({ status: "API ONLINE" });
});

// Listar todos os itens
app.get('/data', async (req, res) => {
  try {
    const items = await readData();
    res.json(items);
  } catch (err) {
    res.status(500).json({ error: 'Erro ao ler dados' });
  }
});

// Criar novo item
app.post('/data', async (req, res) => {
  try {
    const body = req.body || {};
    const items = await readData();

    const newItem = {
      id: Date.now().toString(), // id simples único
      createdAt: new Date().toISOString(),
      ...body
    };

    items.push(newItem);
    await writeData(items);

    res.status(201).json(newItem);
  } catch (err) {
    res.status(500).json({ error: 'Erro ao criar item' });
  }
});

// Atualizar item por id
app.put('/data/:id', async (req, res) => {
  try {
    const id = req.params.id;
    const updates = req.body || {};
    const items = await readData();

    const idx = items.findIndex(i => i.id === id);
    if (idx === -1) return res.status(404).json({ error: 'Item não encontrado' });

    items[idx] = { ...items[idx], ...updates, updatedAt: new Date().toISOString() };
    await writeData(items);

    res.json(items[idx]);
  } catch (err) {
    res.status(500).json({ error: 'Erro ao atualizar item' });
  }
});

// Remover item por id
app.delete('/data/:id', async (req, res) => {
  try {
    const id = req.params.id;
    const items = await readData();

    const idx = items.findIndex(i => i.id === id);
    if (idx === -1) return res.status(404).json({ error: 'Item não encontrado' });

    const removed = items.splice(idx, 1)[0];
    await writeData(items);

    res.json({ deleted: removed });
  } catch (err) {
    res.status(500).json({ error: 'Erro ao apagar item' });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Servidor rodando na porta ${PORT}`));