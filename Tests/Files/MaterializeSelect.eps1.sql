<%= $Binding | Invoke-SqlTemplate -Path ".\Tests\Files\Complex.eps1.sql" -Wrapper 'Materialize' %>
<%= $Binding | Invoke-SqlTemplate -Path ".\Tests\Files\Complex.eps1.sql" %>
