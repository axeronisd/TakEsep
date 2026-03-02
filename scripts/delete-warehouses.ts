import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

async function deleteWarehouses() {
    try {
        // Delete users first (due to foreign key constraints)
        await prisma.user.deleteMany({
            where: {
                warehouse: {
                    name: { in: ['Главный Склад', 'Склад 2 (Филиал)'] }
                }
            }
        })

        // Now delete the warehouses
        const result = await prisma.warehouse.deleteMany({
            where: {
                name: { in: ['Главный Склад', 'Склад 2 (Филиал)'] }
            }
        })

        console.log('Deleted warehouses:', result)
    } catch (error) {
        console.error('Error:', error)
    } finally {
        await prisma.$disconnect()
    }
}

deleteWarehouses()
