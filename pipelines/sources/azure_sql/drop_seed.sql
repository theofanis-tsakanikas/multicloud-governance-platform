-- Empty the Azure SQL source-system schemas so Terraform can drop them — the private-mode twin
-- of drop_seed.py.
--
-- Same job, same reason (T-SQL has no DROP SCHEMA ... CASCADE, and pgssoft/mssql exposes no
-- `drop_cascade`, so `mssql_schema`'s destroy fails while the schema still holds the seeded tables).
-- What differs is who can run it.
--
-- drop_seed.py runs from the GitHub runner, over the public endpoint. In private mode there is no
-- public endpoint, and Azure will not even let you open a firewall rule to pretend otherwise:
--
--     ERROR: (DenyPublicEndpointEnabled) Unable to create or modify firewall rules when public
--     network interface for the server is disabled
--
-- The runner cannot reach the database at all. So the unseed goes where the seed already goes: as a
-- one-shot task on the transit gateway, inside the VPC, across the VPN. That path speaks sqlcmd, not
-- pymssql — hence T-SQL rather than Python.
--
-- ONE BATCH, NO `GO`. sqlcmd -Q takes a single batch, and the task passes this file as one argument.
--
-- It discovers rather than hard-codes, so a seed that grows a table does not need to tell it; and it
-- is a no-op when the objects are already gone, so re-running a failed destroy is safe.

DECLARE @drop NVARCHAR(MAX) = N'';

-- Foreign keys first: a referenced table will not drop while a constraint still points at it, and
-- the failure would be the same class of error this script exists to prevent.
SELECT @drop = @drop + N'ALTER TABLE [' + s.name + N'].[' + t.name + N'] DROP CONSTRAINT [' + fk.name + N'];'
FROM sys.foreign_keys fk
JOIN sys.tables   t ON t.object_id = fk.parent_object_id
JOIN sys.schemas  s ON s.schema_id = t.schema_id
WHERE s.name IN ('inventory', 'orders');

-- Views before tables, for the same reason.
SELECT @drop = @drop + N'DROP VIEW [' + s.name + N'].[' + v.name + N'];'
FROM sys.views v
JOIN sys.schemas s ON s.schema_id = v.schema_id
WHERE s.name IN ('inventory', 'orders');

SELECT @drop = @drop + N'DROP TABLE [' + s.name + N'].[' + t.name + N'];'
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE s.name IN ('inventory', 'orders');

IF @drop = N''
  PRINT '[drop] nothing to unseed — inventory and orders are already empty';
ELSE
  EXEC sp_executesql @drop;

-- Say what is left, so the log proves the schemas are empty rather than asserting it.
SELECT s.name AS remaining_schema, COUNT(o.object_id) AS objects
FROM sys.schemas s
LEFT JOIN sys.objects o
  ON o.schema_id = s.schema_id AND o.type IN ('U', 'V')
WHERE s.name IN ('inventory', 'orders')
GROUP BY s.name;
