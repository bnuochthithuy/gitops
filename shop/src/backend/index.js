const express = require('express');
const cors    = require('cors');
const helmet  = require('helmet');

const app  = express();
const PORT = process.env.PORT || 3000;

app.use(helmet());
app.use(cors());
app.use(express.json());

// ── In-memory data ─────────────────────────────────────────────────────────
const products = [
  { id: 1, name: 'Áo thun nam',       price: 150000, category: 'clothes',     stock: 50, image: 'https://placehold.co/300x300?text=Ao+thun' },
  { id: 2, name: 'Quần jean nữ',      price: 350000, category: 'clothes',     stock: 30, image: 'https://placehold.co/300x300?text=Quan+jean' },
  { id: 3, name: 'Giày sneaker',      price: 650000, category: 'shoes',       stock: 20, image: 'https://placehold.co/300x300?text=Giay' },
  { id: 4, name: 'Balo du lịch',      price: 450000, category: 'bags',        stock: 15, image: 'https://placehold.co/300x300?text=Balo' },
  { id: 5, name: 'Đồng hồ thời trang',price: 1200000,category: 'accessories', stock: 10, image: 'https://placehold.co/300x300?text=Dong+ho' },
  { id: 6, name: 'Kính mắt UV400',    price: 280000, category: 'accessories', stock: 25, image: 'https://placehold.co/300x300?text=Kinh' },
];

let orders = [];
let orderIdCounter = 1;

// ── Health ─────────────────────────────────────────────────────────────────
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', uptime: process.uptime() });
});

// ── Products ───────────────────────────────────────────────────────────────
app.get('/api/products', (req, res) => {
  const { category, search, page = 1, limit = 20 } = req.query;
  let result = [...products];
  if (category) result = result.filter(p => p.category === category);
  if (search)   result = result.filter(p => p.name.toLowerCase().includes(search.toLowerCase()));
  const start = (Number(page) - 1) * Number(limit);
  res.json({ data: result.slice(start, start + Number(limit)), total: result.length });
});

app.get('/api/products/:id', (req, res) => {
  const product = products.find(p => p.id === Number(req.params.id));
  if (!product) return res.status(404).json({ error: 'Sản phẩm không tồn tại' });
  res.json(product);
});

// ── Orders ─────────────────────────────────────────────────────────────────
app.post('/api/orders', (req, res) => {
  const { customerName, customerEmail, customerPhone, address, items } = req.body;
  if (!customerName || !customerEmail || !address || !Array.isArray(items) || !items.length)
    return res.status(400).json({ error: 'Thiếu thông tin đặt hàng' });

  const orderItems = items.map(item => {
    const p = products.find(p => p.id === item.productId);
    if (!p) throw Object.assign(new Error(`Sản phẩm ${item.productId} không tồn tại`), { status: 404 });
    return { productId: p.id, name: p.name, price: p.price, quantity: item.quantity };
  });

  const order = {
    id: orderIdCounter++,
    customerName, customerEmail, customerPhone, address,
    items: orderItems,
    total: orderItems.reduce((s, i) => s + i.price * i.quantity, 0),
    status: 'pending',
    createdAt: new Date(),
  };
  orders.push(order);
  res.status(201).json(order);
});

app.get('/api/orders/:id', (req, res) => {
  const order = orders.find(o => o.id === Number(req.params.id));
  if (!order) return res.status(404).json({ error: 'Đơn hàng không tồn tại' });
  res.json(order);
});

app.listen(PORT, () => console.log(`Backend running on :${PORT}`));
