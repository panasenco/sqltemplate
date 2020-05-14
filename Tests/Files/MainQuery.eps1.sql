WITH <%= Invoke-SqlTemplate -Path .\Tests\Files\subquery1.eps1.sql -Wrapper 'CTE' %>,
<%= Invoke-SqlTemplate -Path .\Tests\Files\subquery2.eps1.sql -Wrapper 'CTE' %>
SELECT
  subquery1.var1,
  subquery2.var2,
  subquery3.var3
FROM subquery1
LEFT JOIN subquery2 ON 2=2
LEFT JOIN <%= Invoke-SqlTemplate -Path .\Tests\Files\subquery3.eps1.sql -Wrapper 'Inline' %> ON 3=3
