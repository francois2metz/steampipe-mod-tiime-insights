dashboard "tiime_dashboard" {
  title = "Tiime Dashboard"

  container {
    card {
      query = query.tiime_billed_this_month
      width = 4
    }

    card {
      query = query.tiime_client_owns
      width = 4
    }

    card {
      query = query.tiime_bank_balance
      width = 4
    }
  }

  container {
    input "period" {
      title = "Select period:"
      width = 2
      sql = <<-EOQ
        select
          label,
          value
        from
          (values
            ('Last 3 month', date_trunc('month', current_date - interval '3 month')),
            ('Last 6 month', date_trunc('month', current_date - interval '6 month')),
            ('Last 12 month', date_trunc('month', current_date - interval '12 month'))
          ) AS t (label, value);

      EOQ
    }

    container {
      card {
        width = 3
        query = query.tiime_period_billed
        args = {
          "label" = "Billed on the selected period"
          "period" = self.input.period.value
        }
      }
    }


    container {
      chart {
        type = "bar"
        title = "Billed by type"
        width = 8

        series benefit {
          title = "Benefit"
          color = "green"
        }
        series sale {
          title = "Sale"
          color = "red"
        }

        query = query.tiime_period_bill_by_month_type
        args = {
          "period" = self.input.period.value
        }
      }

      chart {
        type = "donut"
        title = "Repartition"
        width = 4

        query = query.tiime_period_bill_by_type
        args = {
          "period" = self.input.period.value
        }
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

query "tiime_period_billed" {
  sql = <<-EOQ
    select
      sum(total_excluding_taxes) as value,
      $2 as label,
      'receipt_long' as icon
    from
      tiime_invoice
    where
      emission_date >= $1
  EOQ

  param "period" {}
  param "label" {}
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

query "tiime_bank_balance" {
  sql = <<-EOQ
    select
      sum(balance_amount) as value,
      'Bank balance (all accounts)' as label,
      'account_balance' as icon
    from
      tiime_bank_account
  EOQ
}

query tiime_period_bill_by_month_type {
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

query tiime_period_bill_by_type {
  sql = <<-EOQ
    select
      invoicing_category_type,
      sum(line_amount)
    from
      tiime_invoice,
      jsonb_to_recordset(lines) as specs(invoicing_category_type text, line_amount float)
    where
      emission_date >= $1
    group by
      invoicing_category_type
  EOQ

  param "period" {}
}
