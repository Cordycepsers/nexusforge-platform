"""Create users table

Revision ID: 001
Revises:
Create Date: 2024-01-01 00:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Create users table"""
    op.create_table(
        "users",
        sa.Column(
            "id", sa.Integer(), autoincrement=True, nullable=False, comment="User unique identifier"
        ),
        sa.Column(
            "email", sa.String(length=255), nullable=False, comment="User email address (unique)"
        ),
        sa.Column(
            "username", sa.String(length=100), nullable=False, comment="User username (unique)"
        ),
        sa.Column(
            "hashed_password",
            sa.String(length=255),
            nullable=False,
            comment="Bcrypt hashed password",
        ),
        sa.Column("full_name", sa.String(length=255), nullable=True, comment="User full name"),
        sa.Column("is_active", sa.Boolean(), nullable=False, comment="Account active status"),
        sa.Column("is_verified", sa.Boolean(), nullable=False, comment="Email verification status"),
        sa.Column("is_superuser", sa.Boolean(), nullable=False, comment="Superuser/admin status"),
        sa.Column("last_login_at", sa.DateTime(), nullable=True, comment="Last login timestamp"),
        sa.Column(
            "email_verified_at",
            sa.DateTime(),
            nullable=True,
            comment="Email verification timestamp",
        ),
        sa.Column("created_at", sa.DateTime(), nullable=False, comment="Record creation timestamp"),
        sa.Column(
            "updated_at", sa.DateTime(), nullable=False, comment="Record last update timestamp"
        ),
        sa.Column(
            "deleted_at",
            sa.DateTime(),
            nullable=True,
            comment="Record deletion timestamp (NULL if active)",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_users")),
        comment="User accounts table",
    )

    # Create indexes
    op.create_index(op.f("ix_users_id"), "users", ["id"], unique=False)
    op.create_index(op.f("ix_users_email"), "users", ["email"], unique=True)
    op.create_index(op.f("ix_users_username"), "users", ["username"], unique=True)
    op.create_index("ix_users_email_active", "users", ["email", "is_active"], unique=False)
    op.create_index("ix_users_username_active", "users", ["username", "is_active"], unique=False)
    op.create_index("ix_users_created_at", "users", ["created_at"], unique=False)


def downgrade() -> None:
    """Drop users table"""
    op.drop_index("ix_users_created_at", table_name="users")
    op.drop_index("ix_users_username_active", table_name="users")
    op.drop_index("ix_users_email_active", table_name="users")
    op.drop_index(op.f("ix_users_username"), table_name="users")
    op.drop_index(op.f("ix_users_email"), table_name="users")
    op.drop_index(op.f("ix_users_id"), table_name="users")
    op.drop_table("users")
