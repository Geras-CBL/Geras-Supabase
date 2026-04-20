import 'dotenv/config';
import express, { Request, Response } from 'express';
import cors from 'cors';
import { prisma } from './lib/prisma';

const app = express();
const PORT = process.env.PORT || 3000;

// ==========================================
// MIDDLEWARES GLOBAIS
// ==========================================

// O CORS permite que o teu Front-End (React Native) consiga fazer pedidos a este Back-End
app.use(cors());

// O express.json() permite que o servidor consiga ler o corpo dos pedidos no formato JSON
app.use(express.json());

// ==========================================
// ROTAS
// ==========================================

// Rota de Healthcheck (Apenas para testares se o servidor ligou bem)
app.get('/', async (req: Request, res: Response) => {
  try {
    // Fazemos um teste muito rápido à ligação com a base de dados
    await prisma.$queryRaw`SELECT 1`;
    res.status(200).json({ 
      status: 'success', 
      message: 'Servidor Express do Geras está a correr! 🚀',
      database: 'Conectada com sucesso via Prisma!'
    });
  } catch (error) {
    res.status(500).json({ 
      status: 'error', 
      message: 'Servidor ligado, mas erro na ligação à Base de Dados.',
      error: error instanceof Error ? error.message : 'Erro desconhecido'
    });
  }
});

// As restantes rotas (requests, groceries, users) serão adicionadas aqui futuramente!

// ==========================================
// INICIALIZAÇÃO DO SERVIDOR
// ==========================================

app.listen(PORT, () => {
  console.log(`
Servidor Geras inicializado com sucesso!
A escutar na porta: http://localhost:${PORT}
  `);
});
