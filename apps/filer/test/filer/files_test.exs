defmodule Filer.FilesTest do
  use Filer.DataCase

  alias Filer.Files

  describe "contents" do
    alias Filer.Files.Content

    import Filer.FilesFixtures

    @invalid_attrs %{hash: nil}

    test "list_contents/0 returns all contents" do
      content = content_fixture()
      assert Files.list_contents() == [content]
    end

    test "get_content!/1 returns the content with given id" do
      content = content_fixture()
      assert Files.get_content!(content.id) == content
    end

    test "create_content/1 with valid data creates a content" do
      valid_attrs = %{hash: "some hash"}

      assert {:ok, %Content{} = content} = Files.create_content(valid_attrs)
      assert content.hash == "some hash"
    end

    test "create_content/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Files.create_content(@invalid_attrs)
    end

    test "update_content/2 with valid data updates the content" do
      content = content_fixture()
      update_attrs = %{hash: "some updated hash"}

      assert {:ok, %Content{} = content} = Files.update_content(content, update_attrs)
      assert content.hash == "some updated hash"
    end

    test "update_content/2 with invalid data returns error changeset" do
      content = content_fixture()
      assert {:error, %Ecto.Changeset{}} = Files.update_content(content, @invalid_attrs)
      assert content == Files.get_content!(content.id)
    end

    test "delete_content/1 deletes the content" do
      content = content_fixture()
      assert {:ok, %Content{}} = Files.delete_content(content)
      assert_raise Ecto.NoResultsError, fn -> Files.get_content!(content.id) end
    end

    test "change_content/1 returns a content changeset" do
      content = content_fixture()
      assert %Ecto.Changeset{} = Files.change_content(content)
    end
  end

  describe "files" do
    alias Filer.Files.File

    import Filer.FilesFixtures

    @invalid_attrs %{path: nil}

    test "list_files/0 returns all files" do
      file = file_fixture()
      assert Files.list_files() == [file]
    end

    test "get_file!/1 returns the file with given id" do
      file = file_fixture()
      assert Files.get_file!(file.id) == file
    end

    test "create_file/1 with valid data creates a file" do
      valid_attrs = %{path: "some path"}

      assert {:ok, %File{} = file} = Files.create_file(valid_attrs)
      assert file.path == "some path"
    end

    test "create_file/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Files.create_file(@invalid_attrs)
    end

    test "update_file/2 with valid data updates the file" do
      file = file_fixture()
      update_attrs = %{path: "some updated path"}

      assert {:ok, %File{} = file} = Files.update_file(file, update_attrs)
      assert file.path == "some updated path"
    end

    test "update_file/2 with invalid data returns error changeset" do
      file = file_fixture()
      assert {:error, %Ecto.Changeset{}} = Files.update_file(file, @invalid_attrs)
      assert file == Files.get_file!(file.id)
    end

    test "delete_file/1 deletes the file" do
      file = file_fixture()
      assert {:ok, %File{}} = Files.delete_file(file)
      assert_raise Ecto.NoResultsError, fn -> Files.get_file!(file.id) end
    end

    test "change_file/1 returns a file changeset" do
      file = file_fixture()
      assert %Ecto.Changeset{} = Files.change_file(file)
    end
  end
end
