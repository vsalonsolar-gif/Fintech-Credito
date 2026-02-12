defmodule CreditSystem.Repo.Migrations.AddPgTriggers do
  use Ecto.Migration

  def up do
    # Function to notify on application status changes via pg_notify
    execute """
    CREATE OR REPLACE FUNCTION notify_application_status_change()
    RETURNS trigger AS $$
    BEGIN
      IF OLD.status IS DISTINCT FROM NEW.status THEN
        PERFORM pg_notify('application_status_changes', json_build_object(
          'id', NEW.id,
          'old_status', OLD.status,
          'new_status', NEW.status,
          'country', NEW.country,
          'updated_at', NEW.updated_at
        )::text);
      END IF;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    # Trigger on credit_applications for status changes
    execute """
    CREATE TRIGGER application_status_change_trigger
    AFTER UPDATE ON credit_applications
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION notify_application_status_change();
    """

    # Function to notify on new application creation
    execute """
    CREATE OR REPLACE FUNCTION notify_application_created()
    RETURNS trigger AS $$
    BEGIN
      PERFORM pg_notify('application_created', json_build_object(
        'id', NEW.id,
        'country', NEW.country,
        'status', NEW.status,
        'full_name', NEW.full_name
      )::text);
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE TRIGGER application_created_trigger
    AFTER INSERT ON credit_applications
    FOR EACH ROW
    EXECUTE FUNCTION notify_application_created();
    """
  end

  def down do
    execute "DROP TRIGGER IF EXISTS application_status_change_trigger ON credit_applications;"
    execute "DROP FUNCTION IF EXISTS notify_application_status_change();"
    execute "DROP TRIGGER IF EXISTS application_created_trigger ON credit_applications;"
    execute "DROP FUNCTION IF EXISTS notify_application_created();"
  end
end
