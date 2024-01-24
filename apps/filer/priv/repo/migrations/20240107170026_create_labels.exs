defmodule Filer.Repo.Migrations.CreateLabels do
  use Ecto.Migration

  def change do
    create table(:labels) do
      add :value_id, references(:values, on_delete: :delete_all), null: false
      add :content_id, references(:contents, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:labels, [:value_id])
    create index(:labels, [:content_id])
  end
end
