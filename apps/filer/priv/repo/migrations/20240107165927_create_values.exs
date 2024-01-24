defmodule Filer.Repo.Migrations.CreateValues do
  use Ecto.Migration

  def change do
    create table(:values) do
      add :value, :string, null: false
      add :category_id, references(:categories, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:values, [:category_id])
  end
end
