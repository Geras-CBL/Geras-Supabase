import { Router, Request, Response } from 'express';
import { prisma } from '../lib/prisma';
import { authMiddleware } from '../middlewares/authMiddleware';

const router = Router();

// 1. Listar todas as mercearias (Protegido por login)
router.get('/', authMiddleware, async (req: Request, res: Response) => {
  try {
    const allGroceries = await prisma.groceries.findMany({
      orderBy: { name: 'asc' }
    });
    res.json(allGroceries);
  } catch (error) {
    res.status(500).json({ error: "Erro ao procurar mercearias" });
  }
});

// 2. Criar uma nova mercearia (Protegido por login)
router.post('/', authMiddleware, async (req: Request, res: Response) => {
  const { name, category, unit } = req.body;

  if (!name) {
    return res.status(400).json({ error: "O nome da mercearia é obrigatório" });
  }

  try {
    const newGrocery = await prisma.groceries.create({
      data: {
        name,
        category,
        unit: unit ? parseInt(unit) : null
      }
    });
    res.status(201).json(newGrocery);
  } catch (error) {
    res.status(500).json({ error: "Erro ao criar mercearia" });
  }
});

export default router;
