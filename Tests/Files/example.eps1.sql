SELECT
  Customers.key,
  <%= ($Binding + @{ToFormat='YYYYMMDD'}) | Invoke-SqlTemplate -Template 'Purchases.date' `
      -Wrapper 'DateToString','StringToInt' %> AS PurchaseDateKey,
  <%= ($Binding +
          @{Length=($Binding + @{Substring="' '"}) |
              Invoke-SqlTemplate -Template 'Purchases.fullname' -Wrapper 'SubstringIndex'
          }) | Invoke-SqlTemplate -Template 'Purchases.fullname' -Wrapper 'Substring'
  %> AS PurchaseCode
FROM Purchases
LEFT JOIN Customers ON Purchases.customer_key = Customers.key
