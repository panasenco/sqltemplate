WITH <%= ($Binding + @{Basename='NonRootFruits'}) | Invoke-SqlTemplate -Template "SELECT
  fruit AS fruit
FROM TreeFruits
UNION ALL
SELECT
  fruit AS fruit
FROM BushFruits" -Wrapper 'CTE' %>
SELECT
  fruit
FROM NonRootFruits
UNION ALL
SELECT
  fruit AS fruit
FROM RootFruits
