
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

async function main() {
    console.log('Starting migration to multi-warehouse...');

    // 1. Create Default Warehouse if not exists
    let mainWarehouse = await prisma.warehouse.findFirst({
        where: { name: 'Главный Склад' }
    });

    if (!mainWarehouse) {
        mainWarehouse = await prisma.warehouse.create({
            data: { name: 'Главный Склад' }
        });
        console.log('Created Main Warehouse:', mainWarehouse.id);
    } else {
        console.log('Main Warehouse exists:', mainWarehouse.id);
    }

    // 1.1 Create Second Warehouse
    let secondWarehouse = await prisma.warehouse.findFirst({
        where: { name: 'Склад 2 (Филиал)' }
    });

    if (!secondWarehouse) {
        secondWarehouse = await prisma.warehouse.create({
            data: { name: 'Склад 2 (Филиал)' }
        });
        console.log('Created Second Warehouse:', secondWarehouse.id);
    }

    // 2. Migrate Users
    // Assign all users without warehouse to Main Warehouse
    const users = await prisma.user.updateMany({
        where: { warehouseId: null },
        data: { warehouseId: mainWarehouse.id }
    });
    console.log(`Updated ${users.count} users to Main Warehouse`);

    // 3. Migrate Product Stock
    const products = await prisma.product.findMany();

    for (const product of products) {
        // Check if stock entry exists
        const stock = await prisma.stock.findUnique({
            where: {
                productId_warehouseId: {
                    productId: product.id,
                    warehouseId: mainWarehouse.id
                }
            }
        });

        if (!stock) {
            await prisma.stock.create({
                data: {
                    productId: product.id,
                    warehouseId: mainWarehouse.id,
                    quantity: product.stock // Move legacy stock here
                }
            });
        }

        // Initialize 0 stock for second warehouse
        const stock2 = await prisma.stock.findUnique({
            where: {
                productId_warehouseId: {
                    productId: product.id,
                    warehouseId: secondWarehouse.id
                }
            }
        });

        if (!stock2) {
            await prisma.stock.create({
                data: {
                    productId: product.id,
                    warehouseId: secondWarehouse.id,
                    quantity: 0
                }
            });
        }
    }
    console.log(`Migrated stock for ${products.length} products`);

    // 4. Update Transactions
    const transactions = await prisma.transaction.updateMany({
        where: { warehouseId: null },
        data: { warehouseId: mainWarehouse.id }
    });
    console.log(`Updated ${transactions.count} transactions to Main Warehouse`);

    console.log('Migration completed successfully.');
}

main()
    .catch((e) => {
        console.error(e);
        process.exit(1);
    })
    .finally(async () => {
        await prisma.$disconnect();
    });
