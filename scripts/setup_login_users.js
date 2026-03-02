
const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');

const prisma = new PrismaClient();

async function main() {
    console.log('Setup Login Users...');

    // 1. Get Warehouses
    const mainWarehouse = await prisma.warehouse.findFirst({
        where: { name: 'Главный Склад' }
    });
    const subWarehouse = await prisma.warehouse.findFirst({
        where: { name: 'Склад 2 (Филиал)' }
    });

    if (!mainWarehouse || !subWarehouse) {
        console.error('Warehouses not found! Run migration first.');
        return;
    }

    // 2. Setup Admin (Main Warehouse)
    const adminPassword = await bcrypt.hash('admin123', 10);
    const admin = await prisma.user.upsert({
        where: { username: 'admin' },
        update: {
            warehouseId: mainWarehouse.id,
            role: 'admin'
        },
        create: {
            username: 'admin',
            password: adminPassword,
            role: 'admin',
            warehouseId: mainWarehouse.id
        }
    });
    console.log('User "admin" configured for Main Warehouse.');

    // 3. Setup Manager (Branch Warehouse)
    // Password: 123456
    const managerPassword = await bcrypt.hash('123456', 10);
    const manager = await prisma.user.upsert({
        where: { username: 'manager' },
        update: {
            warehouseId: subWarehouse.id,
            role: 'user' // or admin, if they need full access to their warehouse
        },
        create: {
            username: 'manager',
            password: managerPassword,
            role: 'user',
            warehouseId: subWarehouse.id
        }
    });
    console.log('User "manager" configured for Branch Warehouse.');
}

main()
    .catch((e) => {
        console.error(e);
        process.exit(1);
    })
    .finally(async () => {
        await prisma.$disconnect();
    });
