SELECT
    'ALTER TABLE ' || ac.owner || '.' || ac.table_name || ' DROP CONSTRAINT ' || ac.constraint_name || ';' AS drop_statement,
    CASE ac.constraint_type
        WHEN 'P' THEN 'ALTER TABLE ' || ac.owner || '.' || ac.table_name || ' ADD CONSTRAINT ' || REPLACE(ac.constraint_name, 'SYS_C', 'PK_') || '_NEW PRIMARY KEY (' || LISTAGG(acc.column_name, ', ') WITHIN GROUP (ORDER BY acc.position) || ');'
        WHEN 'U' THEN 'ALTER TABLE ' || ac.owner || '.' || ac.table_name || ' ADD CONSTRAINT ' || REPLACE(ac.constraint_name, 'SYS_C', 'UK_') || '_NEW UNIQUE (' || LISTAGG(acc.column_name, ', ') WITHIN GROUP (ORDER BY acc.position) || ');'
        WHEN 'R' THEN 'ALTER TABLE ' || ac.owner || '.' || ac.table_name || ' ADD CONSTRAINT ' || REPLACE(ac.constraint_name, 'SYS_C', 'FK_') || '_NEW FOREIGN KEY (' || LISTAGG(acc.column_name, ', ') WITHIN GROUP (ORDER BY acc.position) || ') REFERENCES ' || ac.r_owner || '.' || ac.r_constraint_name || ';'
        WHEN 'C' THEN
            -- For CHECK constraints, the search_condition is needed.
            -- This example assumes a simple replacement; more complex parsing might be needed for specific scenarios.
            'ALTER TABLE ' || ac.owner || '.' || ac.table_name || ' ADD CONSTRAINT ' || REPLACE(ac.constraint_name, 'SYS_C', 'CK_') || '_NEW CHECK (' || ac.search_condition || ');'
    END AS add_statement
FROM
    all_constraints ac
JOIN
    all_cons_columns acc ON ac.owner = acc.owner AND ac.constraint_name = acc.constraint_name
WHERE
    ac.owner = 'YOUR_SCHEMA_NAME' -- Replace with the actual schema owner
    AND ac.constraint_type IN ('P', 'U', 'R', 'C') -- Primary Key, Unique, Foreign Key, Check
GROUP BY
    ac.owner, ac.table_name, ac.constraint_name, ac.constraint_type, ac.r_owner, ac.r_constraint_name, ac.search_condition
ORDER BY
    ac.table_name, ac.constraint_name;
