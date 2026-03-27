import {
    Entity,
    PrimaryGeneratedColumn,
    Column,
    CreateDateColumn,
    UpdateDateColumn,
} from 'typeorm';

export enum UserRole {
    OWNER = 'owner',
    ADMIN = 'admin',
    MANAGER = 'manager',
    EMPLOYEE = 'employee',
    VIEWER = 'viewer',
}

@Entity('users')
export class UserEntity {
    @PrimaryGeneratedColumn('uuid')
    id: string;

    @Column({ unique: true })
    email: string;

    @Column({ name: 'display_name' })
    displayName: string;

    @Column({ select: false })
    password: string;

    @Column({ name: 'avatar_url', nullable: true })
    avatarUrl: string;

    @Column({
        type: 'enum',
        enum: UserRole,
        default: UserRole.VIEWER,
    })
    role: UserRole;

    @Column({ name: 'organization_id', nullable: true })
    organizationId: string;

    @CreateDateColumn({ name: 'created_at' })
    createdAt: Date;

    @UpdateDateColumn({ name: 'updated_at' })
    updatedAt: Date;
}
