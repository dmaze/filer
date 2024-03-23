defmodule Filer.Repo.Migrations.CreateModels do
  use Ecto.Migration

  def change do
    create table(:models) do
      add :hash, :string, null: false

      timestamps()
    end

    create unique_index(:models, [:hash])
  end
end
