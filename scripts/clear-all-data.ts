
const { PrismaClient } = require('@prisma/client')

const prisma = new PrismaClient()

async function main() {
    console.log('🗑️  Starting data cleanup...')

    // Order matters due to foreign key constraints

    // 1. Transactions & Audits (Depend on Products/Warehouses)
    await prisma.transaction.deleteMany({})
    console.log('✅ Transactions cleared')

    await prisma.auditItem.deleteMany({})
    await prisma.audit.deleteMany({})
    console.log('✅ Audits cleared')

    // 2. Transfers
    await prisma.transfer.deleteMany({})
    console.log('✅ Transfers cleared')

    // 3. Stocks (Join table)
    await prisma.stock.deleteMany({})
    console.log('✅ Stocks cleared')

    // 4. Products (Core data)
    await prisma.product.deleteMany({})
    console.log('✅ Products cleared')

    // Note: We keeping Warehouses and Users as requested ("from both warehouses" implies warehouses exist)

    console.log('✨ Database operational data wiped successfully!')
    console.log('   (Warehouses and Users were preserved)')
}

main()
    .catch((e) => {
        console.error(e)
        process.exit(1)
    })
    .finally(async () => {
        await prisma.$disconnect()
    })
