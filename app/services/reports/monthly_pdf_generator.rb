# frozen_string_literal: true

require "prawn"
require "prawn/table"

Prawn::Fonts::AFM.hide_m17n_warning = true

module Reports
  class MonthlyPdfGenerator < ApplicationService
    # Design tokens
    INDIGO    = "4F46E5"
    INDIGO_LT = "EEF2FF"
    EMERALD   = "059669"
    ROSE      = "E11D48"
    SLATE_50  = "F8FAFC"
    SLATE_100 = "F1F5F9"
    SLATE_200 = "E2E8F0"
    SLATE_400 = "94A3B8"
    SLATE_600 = "475569"
    SLATE_800 = "1E293B"
    WHITE     = "FFFFFF"

    HEADER_H  = 80
    FOOTER_H  = 40
    LOGO_PATH = Rails.root.join("app/assets/images/vittio_logo.png").to_s

    def initialize(user:, year:, month:)
      @user  = user
      @year  = year.to_i
      @month = month.to_i
    end

    def call
      validate_period!
      load_data
      generate_pdf
    end

    private

    def validate_period!
      raise ArgumentError, "Invalid month" unless @month.between?(1, 12)
      raise ArgumentError, "Invalid year" unless @year.between?(2000, Time.current.year + 1)
    end

    def load_data
      start_date = Date.new(@year, @month, 1)
      end_date   = start_date.end_of_month

      @transactions = @user.transactions
                           .where(date: start_date..end_date)
                           .includes(:category, :bank_account)
                           .order(date: :desc, created_at: :desc)

      income_txns  = @transactions.select { |t| t.transaction_type == "income" }
      expense_txns = @transactions.select { |t| %w[fixed_expense variable_expense].include?(t.transaction_type) }

      @total_income   = income_txns.sum { |t| t.amount.to_f.abs }
      @total_expenses = expense_txns.sum { |t| t.amount.to_f.abs }
      @net            = @total_income - @total_expenses

      @top_categories = expense_txns
        .group_by { |t| t.category }
        .map { |cat, txns| [cat, txns.sum { |t| t.amount.to_f.abs }] }
        .sort_by { |_, total| -total }
        .first(5)

      @bank_accounts = @user.bank_accounts.kept.order(:custom_name)
      @savings       = @user.savings.active.order(:name)   rescue []
      @debts         = @user.debts.active.order(:name)     rescue []

      @period_label = I18n.l(Date.new(@year, @month, 1), format: :month_year, locale: :es)
    rescue NoMethodError
      @period_label = "#{Date::MONTHNAMES[@month]} #{@year}"
    end

    def generate_pdf
      # top margin reserves space for the header band on every page,
      # bottom margin reserves space for the footer band on every page.
      pdf = Prawn::Document.new(
        page_size: "LETTER",
        margin:    [HEADER_H + 16, 48, FOOTER_H + 16, 48],
        info: {
          Title:        "Vittio - Reporte Mensual #{@period_label}",
          Author:       @user.full_name,
          Creator:      "Vittio",
          CreationDate: Time.current
        }
      )

      # Header and footer are drawn in the canvas (absolute page coordinates)
      # so they appear on every page without affecting content flow.
      draw_header(pdf)
      draw_footer(pdf)

      draw_summary(pdf)
      draw_accounts(pdf)
      draw_top_categories(pdf)
      draw_savings_debts(pdf)
      draw_transactions_table(pdf)

      pdf.render
    end

    # ── Header (canvas — absolute coordinates, repeats on all pages) ─────────

    def draw_header(pdf)
      pdf.repeat(:all) do
        pdf.canvas do
          page_w = pdf.bounds.width
          page_h = pdf.bounds.height

          # White band
          pdf.fill_color WHITE
          pdf.fill_rectangle([0, page_h], page_w, HEADER_H)

          # Left indigo accent stripe
          pdf.fill_color INDIGO
          pdf.fill_rectangle([0, page_h], 6, HEADER_H)

          # Bottom border
          pdf.stroke_color SLATE_200
          pdf.line_width 0.5
          pdf.stroke_horizontal_line(0, page_w, at: page_h - HEADER_H)

          # Logo
          logo_w = 110
          logo_h = (logo_w * 277.0 / 734.0).round
          logo_x = 20
          logo_y = page_h - (HEADER_H - logo_h) / 2.0

          if File.exist?(LOGO_PATH)
            pdf.image LOGO_PATH, at: [logo_x, logo_y], width: logo_w
          else
            pdf.fill_color INDIGO
            pdf.text_box "vittio",
              at: [logo_x, page_h - 20], size: 24, style: :bold, width: 120
          end

          title_x = logo_x + logo_w + 16
          pdf.fill_color SLATE_800
          pdf.text_box "Reporte Mensual",
            at: [title_x, page_h - 20], size: 13, style: :bold, width: 200

          pdf.fill_color INDIGO
          pdf.text_box @period_label,
            at: [title_x, page_h - 38], size: 11, width: 200

          generated = begin
            I18n.l(Date.current, format: :long, locale: :es)
          rescue
            Date.current.strftime("%d de %B de %Y")
          end

          pdf.fill_color SLATE_800
          pdf.text_box @user.full_name,
            at: [0, page_h - 22], width: page_w - 16, align: :right, size: 10, style: :bold

          pdf.fill_color SLATE_600
          pdf.text_box "Generado #{generated}",
            at: [0, page_h - 38], width: page_w - 16, align: :right, size: 8
        end
      end
    end

    # ── Footer (canvas — absolute coordinates, repeats on all pages) ─────────

    def draw_footer(pdf)
      pdf.repeat(:all) do
        pdf.canvas do
          page_w = pdf.bounds.width

          # Indigo top rule
          pdf.fill_color INDIGO
          pdf.fill_rectangle([0, FOOTER_H], page_w, 2)

          pdf.fill_color SLATE_400
          pdf.text_box "Vittio  |  #{@period_label}  |  Generado #{Time.current.strftime("%d/%m/%Y %H:%M")}",
            at: [48, FOOTER_H - 8], width: page_w - 96, size: 7, align: :center
        end
      end
    end

    # ── Summary cards ─────────────────────────────────────────────────────────

    def draw_summary(pdf)
      pdf.move_down 8
      col_w = (pdf.bounds.width - 20) / 3.0
      y = pdf.cursor

      [
        ["Ingresos",     format_mxn(@total_income),   EMERALD],
        ["Egresos",      format_mxn(@total_expenses),  ROSE],
        ["Balance Neto", format_mxn(@net),             @net >= 0 ? EMERALD : ROSE]
      ].each_with_index do |(label, amount, color), idx|
        x = idx * (col_w + 10)

        pdf.fill_color SLATE_50
        pdf.fill_rounded_rectangle([x, y], col_w, 64, 6)

        pdf.fill_color color
        pdf.fill_rounded_rectangle([x, y], col_w, 4, 2)

        pdf.text_box amount,
          at: [x + 12, y - 18], width: col_w - 24, size: 13, style: :bold

        pdf.fill_color SLATE_600
        pdf.text_box label,
          at: [x + 12, y - 42], width: col_w - 24, size: 8
      end

      pdf.move_down 80
      pdf.fill_color SLATE_800
    end

    # ── Account balances ───────────────────────────────────────────────────────

    def draw_accounts(pdf)
      return if @bank_accounts.blank?

      section_divider(pdf)
      section_heading(pdf, "Saldo por Cuenta")
      pdf.move_down 14

      col_w  = (pdf.bounds.width - 16) / 2.0
      row_h  = 40
      y_base = pdf.cursor

      @bank_accounts.each_with_index do |account, idx|
        col     = idx % 2
        row     = idx / 2
        x       = col * (col_w + 16)
        y       = y_base - row * (row_h + 10)
        balance = account.effective_balance.to_f
        color   = balance >= 0 ? EMERALD : ROSE

        pdf.fill_color SLATE_50
        pdf.fill_rounded_rectangle([x, y], col_w, row_h, 5)

        # Left indigo tick
        pdf.fill_color INDIGO
        pdf.fill_rounded_rectangle([x, y], 4, row_h, 2)

        pdf.fill_color SLATE_800
        pdf.text_box account.display_name,
          at: [x + 12, y - 10], width: col_w - 90, size: 9, style: :bold, overflow: :truncate

        account_type = account.respond_to?(:account_type) ? account.account_type.to_s.humanize : ""
        pdf.fill_color SLATE_400
        pdf.text_box account_type,
          at: [x + 12, y - 24], width: col_w - 90, size: 7, overflow: :truncate

        pdf.fill_color color
        pdf.text_box format_mxn(balance.abs),
          at: [x, y - 14], width: col_w - 12, size: 12, style: :bold, align: :right
      end

      rows_used = (@bank_accounts.size.to_f / 2).ceil
      pdf.move_down(rows_used * (row_h + 10) + 4)
      pdf.fill_color SLATE_800
    end

    # ── Top categories ─────────────────────────────────────────────────────────

    def draw_top_categories(pdf)
      return if @top_categories.empty?

      section_divider(pdf)
      section_heading(pdf, "Top Categorías de Egresos")
      pdf.move_down 14

      label_w  = 110
      amount_w = 82
      gap      = 10
      bar_x    = label_w + gap
      bar_w_max = pdf.bounds.width - label_w - gap - gap - amount_w
      max = @top_categories.first&.last.to_f

      @top_categories.each do |category, total|
        label = category&.name || "Sin categoría"
        pct   = max.positive? ? (total / max) : 0
        fill  = [bar_w_max * pct, 2].max
        row_y = pdf.cursor

        pdf.fill_color SLATE_800
        pdf.text_box label,
          at: [0, row_y], width: label_w, size: 9, overflow: :truncate

        pdf.fill_color SLATE_100
        pdf.fill_rounded_rectangle([bar_x, row_y - 3], bar_w_max, 13, 3)

        pdf.fill_color INDIGO
        pdf.fill_rounded_rectangle([bar_x, row_y - 3], fill, 13, 3)

        amount_x = bar_x + bar_w_max + gap
        pdf.fill_color SLATE_800
        pdf.text_box format_mxn(total),
          at: [amount_x, row_y], width: amount_w, size: 9, align: :right

        pdf.move_down 24
      end
    end

    # ── Savings & debts ────────────────────────────────────────────────────────

    def draw_savings_debts(pdf)
      has_savings = @savings.present?
      has_debts   = @debts.present?
      return unless has_savings || has_debts

      section_divider(pdf)
      col_w = (pdf.bounds.width - 20) / 2.0
      y_top = pdf.cursor

      draw_savings_col(pdf, 0, col_w, y_top)           if has_savings
      draw_debts_col(pdf, col_w + 20, col_w, y_top)    if has_debts

      consumed = [
        (has_savings ? savings_block_height : 0),
        (has_debts   ? debts_block_height   : 0)
      ].max
      pdf.move_down consumed + 8
    end

    def draw_savings_col(pdf, x_offset, width, y_top)
      pdf.fill_color SLATE_800
      pdf.text_box "Ahorros", at: [x_offset, y_top], width: width, size: 10, style: :bold

      pdf.stroke_color EMERALD
      pdf.line_width 1
      pdf.stroke_horizontal_line(x_offset, x_offset + width, at: y_top - 16)

      y = y_top - 28

      @savings.first(4).each do |saving|
        pct     = saving.respond_to?(:progress_percentage) ? saving.progress_percentage.to_f : 0
        current = saving.respond_to?(:current_amount)      ? saving.current_amount.to_f       : 0
        target  = saving.respond_to?(:target_amount)       ? saving.target_amount.to_f        : 0

        pdf.fill_color SLATE_800
        pdf.text_box saving.name,
          at: [x_offset, y], width: width - 52, size: 8, style: :bold, overflow: :truncate

        pdf.fill_color EMERALD
        pdf.text_box "#{pct.round(0).to_i}%",
          at: [x_offset, y], width: width - 4, size: 8, align: :right

        pdf.fill_color SLATE_200
        pdf.fill_rounded_rectangle([x_offset, y - 13], width, 7, 2)
        fill_w = [(width * pct / 100.0).to_f, 2].max
        pdf.fill_color EMERALD
        pdf.fill_rounded_rectangle([x_offset, y - 13], fill_w, 7, 2)

        pdf.fill_color SLATE_400
        pdf.text_box "#{format_mxn(current)} / #{format_mxn(target)}",
          at: [x_offset, y - 23], width: width, size: 7

        y -= 38
        pdf.fill_color SLATE_800
      end
    end

    def draw_debts_col(pdf, x_offset, width, y_top)
      pdf.fill_color SLATE_800
      pdf.text_box "Deudas", at: [x_offset, y_top], width: width, size: 10, style: :bold

      pdf.stroke_color ROSE
      pdf.line_width 1
      pdf.stroke_horizontal_line(x_offset, x_offset + width, at: y_top - 16)

      y = y_top - 28

      @debts.first(4).each do |debt|
        remaining   = debt.current_balance.to_f
        min_payment = debt.minimum_payment.to_f

        pdf.fill_color SLATE_800
        pdf.text_box debt.name,
          at: [x_offset, y], width: width - 80, size: 8, style: :bold, overflow: :truncate

        pdf.fill_color ROSE
        pdf.text_box format_mxn(remaining),
          at: [x_offset, y], width: width - 4, size: 8, align: :right

        if min_payment.positive?
          pdf.fill_color SLATE_400
          pdf.text_box "Pago minimo: #{format_mxn(min_payment)}",
            at: [x_offset, y - 14], width: width, size: 7
        end

        y -= (min_payment.positive? ? 32 : 22)
        pdf.fill_color SLATE_800
      end
    end

    def savings_block_height
      28 + (@savings.first(4).size * 38)
    end

    def debts_block_height
      height = 28
      @debts.first(4).each { |d| height += d.minimum_payment.to_f.positive? ? 32 : 22 }
      height
    end

    # ── Transactions table ────────────────────────────────────────────────────

    def draw_transactions_table(pdf)
      section_divider(pdf)
      section_heading(pdf, "Movimientos del Mes")
      pdf.move_down 14

      if @transactions.empty?
        pdf.fill_color SLATE_400
        pdf.text "No hay movimientos en este periodo.", size: 10
        pdf.fill_color SLATE_800
        return
      end

      headers = [["Fecha", "Descripcion", "Categoria", "Cuenta", "Monto"]]

      rows = @transactions.map do |t|
        income = t.transaction_type == "income"
        sign   = income ? "+" : "-"
        [
          t.date.strftime("%d/%m"),
          t.description.to_s.truncate(40),
          t.category&.name || "-",
          t.bank_account&.display_name.to_s.truncate(22),
          "#{sign} #{format_mxn(t.amount.to_f.abs)}"
        ]
      end

      pdf.table(headers + rows, width: pdf.bounds.width, header: true) do |tbl|
        tbl.cells.borders      = [:bottom]
        tbl.cells.border_color = SLATE_200
        tbl.cells.border_width = 0.5
        tbl.cells.size         = 8
        tbl.cells.padding      = [6, 6]

        tbl.row(0).background_color = INDIGO_LT
        tbl.row(0).text_color       = INDIGO
        tbl.row(0).font_style       = :bold
        tbl.row(0).borders          = [:bottom]
        tbl.row(0).border_color     = INDIGO
        tbl.row(0).border_width     = 1.5

        @transactions.each_with_index do |txn, i|
          row = i + 1
          tbl.row(row).background_color = i.odd? ? SLATE_50 : WHITE
          income = txn.transaction_type == "income"
          tbl.row(row).column(4).text_color = income ? EMERALD : ROSE
        end

        tbl.column(0).width = 42
        tbl.column(2).width = 82
        tbl.column(3).width = 98
        tbl.column(4).width = 80
        tbl.column(4).align = :right
        tbl.column(0).align = :center
      end
    rescue Prawn::Errors::CannotFit
      pdf.fill_color SLATE_400
      pdf.text "Tabla de movimientos no disponible.", size: 9
      pdf.fill_color SLATE_800
    end

    # ── Helpers ───────────────────────────────────────────────────────────────

    def section_divider(pdf)
      pdf.move_down 28
      pdf.stroke_color SLATE_100
      pdf.line_width 1
      pdf.stroke_horizontal_rule
      pdf.move_down 20
    end

    def section_heading(pdf, text)
      pdf.fill_color SLATE_800
      pdf.font_size 11 do
        pdf.text text, style: :bold
      end
      pdf.move_down 2
    end

    def format_mxn(amount)
      ActionController::Base.helpers.number_to_currency(
        amount, unit: "MX$", separator: ".", delimiter: ",", precision: 2
      )
    end
  end
end
