import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

async function main() {
    const warehouses = await prisma.warehouse.findMany()

    for (const w of warehouses) {
        let newName = w.name
        if (w.name === 'Главный склад') newName = 'Склад 1'
        if (w.name === 'Филиал') newName = 'Склад 2'

        if (newName !== w.name) {
            await prisma.warehouse.update({
                where: { id: w.id },
                data: { name: newName }
            })
            console.log(`Updated warehouse ${w.name} to ${newName}`)
        }
    }
}

main()
    .catch(e => {
        console.error(e)
        process.exit(1)
    })
    .finally(async () => {
        await prisma.$disconnect()
    })
