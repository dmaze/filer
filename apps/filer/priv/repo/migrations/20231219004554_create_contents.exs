defmodule Filer.Repo.Migrations.CreateContents do
  use Ecto.Migration

  def change do
    create table(:contents) do
      add :hash, :string, null: false

      timestamps()
    end

    create unique_index(:contents, [:hash])
  end
end
