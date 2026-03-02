const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

async function main() {
    console.log('Testing Prisma connection...');
    try {
        const count = await prisma.user.count();
        console.log('Current user count:', count);
    } catch (e) {
        console.error('Prisma error:', e);
    }
}

main()
    .then(async () => {
        await prisma.$disconnect();
    })
    .catch(async (e) => {
        console.error(e);
        await prisma.$disconnect();
        process.exit(1);
    });
