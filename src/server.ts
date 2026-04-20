import 'dotenv/config';
import express, { Request, Response } from 'express';
import cors from 'cors';
import { prisma } from './lib/prisma';
import routes from './routes';

const app = express();
const PORT = process.env.PORT || 3000;
app.use(cors());
app.use(express.json());

app.get('/', async (req: Request, res: Response) => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    res.status(200).json({ 
      status: 'success', 
      message: 'Servidor Express do Geras está a correr! 🚀'
    });
  } catch (error) {
    res.status(500).json({ status: 'error', message: 'Erro na BD' });
  }
});

app.use(routes);

app.listen(PORT, () => {
  console.log(`Servidor a correr em: http://localhost:${PORT}`);
});
