import { PrismaClient } from '@prisma/client'
import bcrypt from 'bcryptjs'

const prisma = new PrismaClient()

async function main() {
    console.log('Starting multi-tenant system setup...')

    // Create warehouses
    const warehouse1 = await prisma.warehouse.upsert({
        where: { name: 'Склад 1' },
        update: {},
        create: {
            name: 'Склад 1',
        },
    })

    const warehouse2 = await prisma.warehouse.upsert({
        where: { name: 'Склад 2' },
        update: {},
        create: {
            name: 'Склад 2',
        },
    })

    console.log('Created warehouses:', warehouse1.name, warehouse2.name)

    // Create users for each warehouse
    const hashedPassword1 = await bcrypt.hash('admin', 10)
    const hashedPassword2 = await bcrypt.hash('123456', 10)

    const admin1 = await prisma.user.upsert({
        where: { username: 'admin' },
        update: {},
        create: {
            username: 'admin',
            password: hashedPassword1,
            role: 'admin',
            warehouseId: warehouse1.id,
        },
    })

    const admin2 = await prisma.user.upsert({
        where: { username: 'admin2' },
        update: {},
        create: {
            username: 'admin2',
            password: hashedPassword2,
            role: 'admin',
            warehouseId: warehouse2.id,
        },
    })

    console.log('Created administrators:')
    console.log('   - Warehouse 1: admin / admin')
    console.log('   - Warehouse 2: admin2 / 123456')

    // Create test products
    const product1 = await prisma.product.upsert({
        where: { barcode: '1234567890123' },
        update: {},
        create: {
            name: 'Test Product 1',
            barcode: '1234567890123',
            buyPrice: 100,
            sellPrice: 150,
        },
    })

    const product2 = await prisma.product.upsert({
        where: { barcode: '9876543210987' },
        update: {},
        create: {
            name: 'Test Product 2',
            barcode: '9876543210987',
            buyPrice: 200,
            sellPrice: 300,
        },
    })

    // Create stock for each warehouse
    await prisma.stock.upsert({
        where: {
            productId_warehouseId: {
                productId: product1.id,
                warehouseId: warehouse1.id,
            },
        },
        update: { quantity: 50 },
        create: {
            productId: product1.id,
            warehouseId: warehouse1.id,
            quantity: 50,
        },
    })

    await prisma.stock.upsert({
        where: {
            productId_warehouseId: {
                productId: product1.id,
                warehouseId: warehouse2.id,
            },
        },
        update: { quantity: 30 },
        create: {
            productId: product1.id,
            warehouseId: warehouse2.id,
            quantity: 30,
        },
    })

    await prisma.stock.upsert({
        where: {
            productId_warehouseId: {
                productId: product2.id,
                warehouseId: warehouse1.id,
            },
        },
        update: { quantity: 25 },
        create: {
            productId: product2.id,
            warehouseId: warehouse1.id,
            quantity: 25,
        },
    })

    await prisma.stock.upsert({
        where: {
            productId_warehouseId: {
                productId: product2.id,
                warehouseId: warehouse2.id,
            },
        },
        update: { quantity: 40 },
        create: {
            productId: product2.id,
            warehouseId: warehouse2.id,
            quantity: 40,
        },
    })

    console.log('Created stock levels for both warehouses')
    console.log('System ready for multi-tenant operation!')
}

main()
    .then(async () => {
        await prisma.$disconnect()
    })
    .catch(async (e) => {
        console.error(e)
        await prisma.$disconnect()
        process.exit(1)
    })