import { PrismaClient } from '@prisma/client'
import bcrypt from 'bcryptjs'

const prisma = new PrismaClient()

async function main() {
    console.log('🔧 Setting up 3 warehouses with groups...')

    // ========== Clear existing data ==========
    console.log('Clearing existing warehouses and groups...')

    // Delete in order of dependencies
    await prisma.auditItem.deleteMany()
    await prisma.audit.deleteMany()
    await prisma.transfer.deleteMany()
    await prisma.transaction.deleteMany()
    await prisma.stock.deleteMany()
    await prisma.financialTransaction.deleteMany()
    await prisma.employee.deleteMany()
    await prisma.product.deleteMany()
    await prisma.user.deleteMany()
    await prisma.warehouse.deleteMany()
    await prisma.warehouseGroup.deleteMany()

    // ========== Create Groups ==========
    const phonesGroup = await prisma.warehouseGroup.create({
        data: { name: 'Телефоны' }
    })

    const evGroup = await prisma.warehouseGroup.create({
        data: { name: 'Электромуравьи' }
    })

    console.log('✅ Created groups:', phonesGroup.name, evGroup.name)

    // ========== Create Warehouses ==========
    const phonesWarehouse = await prisma.warehouse.create({
        data: {
            name: 'Телефоны',
            groupId: phonesGroup.id,
        }
    })

    const evBranch1 = await prisma.warehouse.create({
        data: {
            name: 'Электромуравьи — Филиал 1',
            groupId: evGroup.id,
        }
    })

    const evBranch2 = await prisma.warehouse.create({
        data: {
            name: 'Электромуравьи — Филиал 2',
            groupId: evGroup.id,
        }
    })

    console.log('✅ Created warehouses:', phonesWarehouse.name, evBranch1.name, evBranch2.name)

    // ========== Create Users ==========
    const hash = await bcrypt.hash('1234', 10)

    await prisma.user.create({
        data: {
            username: 'phones',
            password: hash,
            role: 'admin',
            warehouseId: phonesWarehouse.id,
        }
    })

    await prisma.user.create({
        data: {
            username: 'ev1',
            password: hash,
            role: 'admin',
            warehouseId: evBranch1.id,
        }
    })

    await prisma.user.create({
        data: {
            username: 'ev2',
            password: hash,
            role: 'admin',
            warehouseId: evBranch2.id,
        }
    })

    console.log('✅ Created users:')
    console.log('   📱 Телефоны:              phones / 1234')
    console.log('   🛴 Электромуравьи Ф1:     ev1 / 1234')
    console.log('   🛴 Электромуравьи Ф2:     ev2 / 1234')

    // ========== Sample Products ==========
    // Phone products
    const phoneProducts = [
        { name: 'iPhone 15 Pro Max 256GB', barcode: '8901234567890', buyPrice: 45000, sellPrice: 55000 },
        { name: 'Samsung Galaxy S24 Ultra', barcode: '8901234567891', buyPrice: 42000, sellPrice: 52000 },
        { name: 'Чехол iPhone 15 Pro Max силикон', barcode: '8901234567892', buyPrice: 200, sellPrice: 500 },
        { name: 'Защитное стекло iPhone 15', barcode: '8901234567893', buyPrice: 100, sellPrice: 350 },
        { name: 'Кабель USB-C Lightning 1m', barcode: '8901234567894', buyPrice: 150, sellPrice: 400 },
    ]

    for (const p of phoneProducts) {
        const product = await prisma.product.create({
            data: {
                name: p.name,
                barcode: p.barcode,
                buyPrice: p.buyPrice,
                sellPrice: p.sellPrice,
                warehouseGroupId: phonesGroup.id,
            }
        })
        await prisma.stock.create({
            data: {
                productId: product.id,
                warehouseId: phonesWarehouse.id,
                quantity: Math.floor(Math.random() * 20) + 5,
            }
        })
    }

    // EV products (shared between both branches)
    const evProducts = [
        { name: 'Электросамокат Kugoo S3 Pro', barcode: '7901234567890', buyPrice: 12000, sellPrice: 18000 },
        { name: 'Электросамокат Ninebot Max G30', barcode: '7901234567891', buyPrice: 25000, sellPrice: 35000 },
        { name: 'Камера 10x2.5 для самоката', barcode: '7901234567892', buyPrice: 300, sellPrice: 700 },
        { name: 'Покрышка 10x2.5', barcode: '7901234567893', buyPrice: 400, sellPrice: 900 },
        { name: 'Контроллер 36V для Kugoo', barcode: '7901234567894', buyPrice: 1500, sellPrice: 3000 },
        { name: 'Тормозные колодки дисковые', barcode: '7901234567895', buyPrice: 100, sellPrice: 300 },
        { name: 'Аккумулятор 36V 10Ah', barcode: '7901234567896', buyPrice: 5000, sellPrice: 8000 },
        { name: 'Зарядное устройство 42V 2A', barcode: '7901234567897', buyPrice: 800, sellPrice: 1500 },
    ]

    for (const p of evProducts) {
        const product = await prisma.product.create({
            data: {
                name: p.name,
                barcode: p.barcode,
                buyPrice: p.buyPrice,
                sellPrice: p.sellPrice,
                warehouseGroupId: evGroup.id,
            }
        })
        // Stock for both EV branches
        await prisma.stock.create({
            data: {
                productId: product.id,
                warehouseId: evBranch1.id,
                quantity: Math.floor(Math.random() * 15) + 3,
            }
        })
        await prisma.stock.create({
            data: {
                productId: product.id,
                warehouseId: evBranch2.id,
                quantity: Math.floor(Math.random() * 10) + 2,
            }
        })
    }

    console.log('✅ Created sample products: 5 phone + 8 EV')
    console.log('')
    console.log('🎉 Setup complete!')
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
