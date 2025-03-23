dashboard "tiime_dashboard" {
  title = "Tiime Dashboard"

  container {
    card {
      query = query.tiime_billed_this_month
      width = 3
    }

    card {
      query = query.tiime_client_owns
      width = 3
    }
  }

  container {
    input "period" {
      title = "Select period:"
      width = 2
      sql = <<-EOQ
        select
          *
        from
          (values
            ('Last 3 month', date_trunc('month', current_date - interval '3 month')),
            ('Last 6 month', date_trunc('month', current_date - interval '6 month')),
            ('Last 12 month', date_trunc('month', current_date - interval '12 month'))
          ) AS t (label, value);

      EOQ
    }

    chart {
      type = "bar"
      title = "Billed by type"

      legend {
        display  = "auto"
        position = "top"
      }

      series benefit {
        title = "Benefit"
        color = "green"
      }
      series sale {
        title = "Sale"
        color = "red"
      }

      query = query.tiime_bill_by_type
      args = {
        "period" = self.input.period.value
      }
    }
  }
}

query "tiime_billed_this_month" {
  sql = <<-EOQ
    select
      sum(total_excluding_taxes) as value,
      'Billed this month (without taxes)' as label,
      'receipt_long' as icon
     from
      tiime_invoice
    where
      emission_date >= date_trunc('month', current_date)
  EOQ
}

query "tiime_client_owns" {
  sql = <<-EOQ
    select
      sum(balance_including_taxes) as value,
      'Clients own you (with taxes)' as label,
      'face' as icon
    from
      tiime_client
  EOQ
}

query tiime_bill_by_type {
  sql = <<-EOQ
    with invoices as (
      select
        to_char(date_trunc('month', emission_date), 'YYYY-MM') as emission_date,
        invoicing_category_type,
        line_amount
      from
        tiime_invoice,
        jsonb_to_recordset(lines) as specs(invoicing_category_type text, line_amount float)
      where
        emission_date >= $1
    ), benefits as (
      select
        emission_date,
        sum(line_amount) as amount
      from
        invoices
      where
        invoicing_category_type = 'benefit'
      group by
        emission_date
    ), sales as (
      select
        emission_date,
        sum(line_amount) as amount
      from
        invoices
      where
        invoicing_category_type = 'sale'
      group by
        emission_date
    )
    select
      b.emission_date,
      b.amount as benefit,
      s.amount as sale
    from
      benefits as b
    full join
      sales s
    on
      b.emission_date = s.emission_date
    order by
      emission_date
  EOQ

  param "period" {}
}
