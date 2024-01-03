defmodule Filer.Repo.Migrations.CreateFiles do
  use Ecto.Migration

  def change do
    create table(:files) do
      add :path, :string, null: false
      add :content_id, references(:contents, on_delete: :nothing), null: false

      timestamps()
    end

    create index(:files, [:content_id])
    create unique_index(:files, [:path])
  end
end
