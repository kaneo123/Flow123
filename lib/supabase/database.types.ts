export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "13.0.5"
  }
  public: {
    Tables: {
      app_versions: {
        Row: {
          file_sha256: string | null
          file_size_bytes: number | null
          id: string
          latest_version: string
          minimum_version: string
          platform: string
          published_at: string | null
          release_notes: string | null
          storage_path: string | null
        }
        Insert: {
          file_sha256?: string | null
          file_size_bytes?: number | null
          id?: string
          latest_version: string
          minimum_version: string
          platform: string
          published_at?: string | null
          release_notes?: string | null
          storage_path?: string | null
        }
        Update: {
          file_sha256?: string | null
          file_size_bytes?: number | null
          id?: string
          latest_version?: string
          minimum_version?: string
          platform?: string
          published_at?: string | null
          release_notes?: string | null
          storage_path?: string | null
        }
        Relationships: []
      }
      categories: {
        Row: {
          active: boolean
          created_at: string
          description: string | null
          id: string
          name: string
          outlet_id: string
          parent_id: string | null
          sort_order: number
        }
        Insert: {
          active?: boolean
          created_at?: string
          description?: string | null
          id?: string
          name: string
          outlet_id: string
          parent_id?: string | null
          sort_order?: number
        }
        Update: {
          active?: boolean
          created_at?: string
          description?: string | null
          id?: string
          name?: string
          outlet_id?: string
          parent_id?: string | null
          sort_order?: number
        }
        Relationships: [
          {
            foreignKeyName: "categories_outlet_id_fkey"
            columns: ["outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "categories_parent_id_fkey"
            columns: ["parent_id"]
            isOneToOne: false
            referencedRelation: "categories"
            referencedColumns: ["id"]
          },
        ]
      }
      device_sync_log: {
        Row: {
          created_at: string
          details: Json | null
          device_id: string
          error_message: string | null
          event_type: string
          id: string
          ops_count: number | null
          order_id: string | null
          outlet_id: string | null
          table_id: string | null
        }
        Insert: {
          created_at?: string
          details?: Json | null
          device_id: string
          error_message?: string | null
          event_type: string
          id?: string
          ops_count?: number | null
          order_id?: string | null
          outlet_id?: string | null
          table_id?: string | null
        }
        Update: {
          created_at?: string
          details?: Json | null
          device_id?: string
          error_message?: string | null
          event_type?: string
          id?: string
          ops_count?: number | null
          order_id?: string | null
          outlet_id?: string | null
          table_id?: string | null
        }
        Relationships: []
      }
      devices: {
        Row: {
          created_at: string | null
          device_id: string
          device_name: string
          device_role: string
          id: string
          is_active: boolean | null
          is_print_worker: boolean | null
          last_seen_at: string | null
          outlet_id: string
          parent_device_id: string | null
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          device_id: string
          device_name: string
          device_role?: string
          id?: string
          is_active?: boolean | null
          is_print_worker?: boolean | null
          last_seen_at?: string | null
          outlet_id: string
          parent_device_id?: string | null
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          device_id?: string
          device_name?: string
          device_role?: string
          id?: string
          is_active?: boolean | null
          is_print_worker?: boolean | null
          last_seen_at?: string | null
          outlet_id?: string
          parent_device_id?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "devices_outlet_id_fkey"
            columns: ["outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "devices_parent_device_id_fkey"
            columns: ["parent_device_id"]
            isOneToOne: false
            referencedRelation: "devices"
            referencedColumns: ["id"]
          },
        ]
      }
      inventory_item_barcodes: {
        Row: {
          barcode: string
          created_at: string
          id: string
          inventory_item_id: string
          is_primary: boolean
          outlet_id: string
          unit_type: string
        }
        Insert: {
          barcode: string
          created_at?: string
          id?: string
          inventory_item_id: string
          is_primary?: boolean
          outlet_id: string
          unit_type?: string
        }
        Update: {
          barcode?: string
          created_at?: string
          id?: string
          inventory_item_id?: string
          is_primary?: boolean
          outlet_id?: string
          unit_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "inventory_item_barcodes_inventory_item_id_fkey"
            columns: ["inventory_item_id"]
            isOneToOne: false
            referencedRelation: "inventory_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_item_barcodes_outlet_id_fkey"
            columns: ["outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
        ]
      }
      inventory_items: {
        Row: {
          category: string | null
          created_at: string
          current_qty: number
          id: string
          linked_product_id: string | null
          location: string | null
          name: string
          outlet_id: string
          pack_quantity: number
          par_days: number
          par_level: number | null
          par_mode: string
          par_target_days: number
          sku: string | null
          supplier: string | null
          unit: string
          unit_cost: number
        }
        Insert: {
          category?: string | null
          created_at?: string
          current_qty?: number
          id?: string
          linked_product_id?: string | null
          location?: string | null
          name: string
          outlet_id: string
          pack_quantity?: number
          par_days?: number
          par_level?: number | null
          par_mode?: string
          par_target_days?: number
          sku?: string | null
          supplier?: string | null
          unit?: string
          unit_cost?: number
        }
        Update: {
          category?: string | null
          created_at?: string
          current_qty?: number
          id?: string
          linked_product_id?: string | null
          location?: string | null
          name?: string
          outlet_id?: string
          pack_quantity?: number
          par_days?: number
          par_level?: number | null
          par_mode?: string
          par_target_days?: number
          sku?: string | null
          supplier?: string | null
          unit?: string
          unit_cost?: number
        }
        Relationships: [
          {
            foreignKeyName: "inventory_items_linked_product_id_fkey"
            columns: ["linked_product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_items_outlet_id_fkey"
            columns: ["outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
        ]
      }
      modifier_groups: {
        Row: {
          active: boolean
          created_at: string
          description: string | null
          id: string
          is_required: boolean
          max_select: number
          min_select: number
          name: string
          outlet_id: string
          selection_type: string
          sort_order: number
        }
        Insert: {
          active?: boolean
          created_at?: string
          description?: string | null
          id?: string
          is_required?: boolean
          max_select?: number
          min_select?: number
          name: string
          outlet_id: string
          selection_type?: string
          sort_order?: number
        }
        Update: {
          active?: boolean
          created_at?: string
          description?: string | null
          id?: string
          is_required?: boolean
          max_select?: number
          min_select?: number
          name?: string
          outlet_id?: string
          selection_type?: string
          sort_order?: number
        }
        Relationships: [
          {
            foreignKeyName: "modifier_groups_outlet_id_fkey"
            columns: ["outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
        ]
      }
      modifier_options: {
        Row: {
          active: boolean
          created_at: string
          group_id: string
          id: string
          is_default: boolean
          name: string
          outlet_id: string
          price_delta: number
          sort_order: number
        }
        Insert: {
          active?: boolean
          created_at?: string
          group_id: string
          id?: string
          is_default?: boolean
          name: string
          outlet_id: string
          price_delta?: number
          sort_order?: number
        }
        Update: {
          active?: boolean
          created_at?: string
          group_id?: string
          id?: string
          is_default?: boolean
          name?: string
          outlet_id?: string
          price_delta?: number
          sort_order?: number
        }
        Relationships: [
          {
            foreignKeyName: "modifier_options_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "modifier_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "modifier_options_outlet_id_fkey"
            columns: ["outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
        ]
      }
      order_activity_log: {
        Row: {
          action_description: string
          action_type: string
          created_at: string
          id: string
          meta: Json | null
          order_id: string
          outlet_id: string
          staff_id: string | null
          table_id: string | null
        }
        Insert: {
          action_description: string
          action_type: string
          created_at?: string
          id?: string
          meta?: Json | null
          order_id: string
          outlet_id: string
          staff_id?: string | null
          table_id?: string | null
        }
        Update: {
          action_description?: string
          action_type?: string
          created_at?: string
          id?: string
          meta?: Json | null
          order_id?: string
          outlet_id?: string
          staff_id?: string | null
          table_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "order_activity_log_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_activity_log_outlet_id_fkey"
            columns: ["outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_activity_log_staff_id_fkey"
            columns: ["staff_id"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
        ]
      }
      order_conflicts: {
        Row: {
          client_version: Json
          conflict_type: string
          created_at: string
          detected_at: string
          device_id: string | null
          id: string
          merged_version: Json | null
          meta: Json | null
          order_id: string
          outlet_id: string
          resolution_strategy: string | null
          resolved_at: string | null
          server_version: Json
          session_id: string | null
          severity: string
          status: string
          updated_at: string
        }
        Insert: {
          client_version: Json
          conflict_type: string
          created_at?: string
          detected_at?: string
          device_id?: string | null
          id?: string
          merged_version?: Json | null
          meta?: Json | null
          order_id: string
          outlet_id: string
          resolution_strategy?: string | null
          resolved_at?: string | null
          server_version: Json
          session_id?: string | null
          severity?: string
          status?: string
          updated_at?: string
        }
        Update: {
          client_version?: Json
          conflict_type?: string
          created_at?: string
          detected_at?: string
          device_id?: string | null
          id?: string
          merged_version?: Json | null
          meta?: Json | null
          order_id?: string
          outlet_id?: string
          resolution_strategy?: string | null
          resolved_at?: string | null
          server_version?: Json
          session_id?: string | null
          severity?: string
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "order_conflicts_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_conflicts_outlet_id_fkey"
            columns: ["outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
        ]
      }
      order_item_modifiers: {
        Row: {
          created_at: string
          group_id: string | null
          id: string
          option_id: string | null
          option_name_snapshot: string
          order_item_id: string
          outlet_id: string
          price_delta_snapshot: number
        }
        Insert: {
          created_at?: string
          group_id?: string | null
          id?: string
          option_id?: string | null
          option_name_snapshot: string
          order_item_id: string
          outlet_id: string
          price_delta_snapshot?: number
        }
        Update: {
          created_at?: string
          group_id?: string | null
          id?: string
          option_id?: string | null
          option_name_snapshot?: string
          order_item_id?: string
          outlet_id?: string
          price_delta_snapshot?: number
        }
        Relationships: [
          {
            foreignKeyName: "order_item_modifiers_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "modifier_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_item_modifiers_option_id_fkey"
            columns: ["option_id"]
            isOneToOne: false
            referencedRelation: "modifier_options"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_item_modifiers_order_item_id_fkey"
            columns: ["order_item_id"]
            isOneToOne: false
            referencedRelation: "order_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_item_modifiers_outlet_id_fkey"
            columns: ["outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
        ]
      }
      order_items: {
        Row: {
          category_id: string | null
          course: string | null
          created_at: string
          discount_amount: number
          gross_line_total: number
          id: string
          inventory_item_id: string | null
          modifier_line_id: string | null
          modifiers: Json | null
          net_line_total: number
          notes: string | null
          order_id: string
          outlet_id: string | null
          plu: string | null
          product_id: string | null
          product_name: string
          quantity: number
          sort_order: number
          tax_amount: number
          tax_rate: number
          unit_price: number
          updated_at: string
        }
        Insert: {
          category_id?: string | null
          course?: string | null
          created_at?: string
          discount_amount?: number
          gross_line_total?: number
          id?: string
          inventory_item_id?: string | null
          modifier_line_id?: string | null
          modifiers?: Json | null
          net_line_total?: number
          notes?: string | null
          order_id: string
          outlet_id?: string | null
          plu?: string | null
          product_id?: string | null
          product_name: string
          quantity?: number
          sort_order?: number
          tax_amount?: number
          tax_rate?: number
          unit_price?: number
          updated_at?: string
        }
        Update: {
          category_id?: string | null
          course?: string | null
          created_at?: string
          discount_amount?: number
          gross_line_total?: number
          id?: string
          inventory_item_id?: string | null
          modifier_line_id?: string | null
          modifiers?: Json | null
          net_line_total?: number
          notes?: string | null
          order_id?: string
          outlet_id?: string | null
          plu?: string | null
          product_id?: string | null
          product_name?: string
          quantity?: number
          sort_order?: number
          tax_amount?: number
          tax_rate?: number
          unit_price?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "order_items_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_items_inventory_item_id_fkey"
            columns: ["inventory_item_id"]
            isOneToOne: false
            referencedRelation: "inventory_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_items_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_items_outlet_id_fkey"
            columns: ["outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_items_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      order_operations: {
        Row: {
          applied_at: string | null
          created_at: string
          device_id: string
          error_message: string | null
          id: string
          op_type: string
          order_id: string | null
          outlet_id: string
          row_data: Json
          status: string
          table_name: string
        }
        Insert: {
          applied_at?: string | null
          created_at?: string
          device_id: string
          error_message?: string | null
          id?: string
          op_type: string
          order_id?: string | null
          outlet_id: string
          row_data?: Json
          status?: string
          table_name: string
        }
        Update: {
          applied_at?: string | null
          created_at?: string
          device_id?: string
          error_message?: string | null
          id?: string
          op_type?: string
          order_id?: string | null
          outlet_id?: string
          row_data?: Json
          status?: string
          table_name?: string
        }
        Relationships: [
          {
            foreignKeyName: "order_operations_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_operations_outlet_id_fkey"
            columns: ["outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
        ]
      }
      orders: {
        Row: {
          change_due: number
          completed_at: string | null
          covers: number | null
          created_at: string
          customer_name: string | null
          discount_amount: number
          id: string
          loyalty_redeemed: number
          notes: string | null
          opened_at: string
          order_type: string
          outlet_id: string
          parked_at: string | null
          payment_method: string | null
          server_hash: string | null
          server_version: number
          service_charge: number
          staff_id: string | null
          status: string
          subtotal: number
          tab_name: string | null
          table_id: string | null
          table_number: string | null
          tax_amount: number
          total_due: number
          total_paid: number | null
          updated_at: string
          voucher_amount: number
        }
        Insert: {
          change_due?: number
          completed_at?: string | null
          covers?: number | null
          created_at?: string
          customer_name?: string | null
          discount_amount?: number
          id?: string
          loyalty_redeemed?: number
          notes?: string | null
          opened_at?: string
          order_type?: string
          outlet_id: string
          parked_at?: string | null
          payment_method?: string | null
          server_hash?: string | null
          server_version?: number
          service_charge?: number
          staff_id?: string | null
          status?: string
          subtotal?: number
          tab_name?: string | null
          table_id?: string | null
          table_number?: string | null
          tax_amount?: number
          total_due?: number
          total_paid?: number | null
          updated_at?: string
          voucher_amount?: number
        }
        Update: {
          change_due?: number
          completed_at?: string | null
          covers?: number | null
          created_at?: string
          customer_name?: string | null
          discount_amount?: number
          id?: string
          loyalty_redeemed?: number
          notes?: string | null
          opened_at?: string
          order_type?: string
          outlet_id?: string
          parked_at?: string | null
          payment_method?: string | null
          server_hash?: string | null
          server_version?: number
          service_charge?: number
          staff_id?: string | null
          status?: string
          subtotal?: number
          tab_name?: string | null
          table_id?: string | null
          table_number?: string | null
          tax_amount?: number
          total_due?: number
          total_paid?: number | null
          updated_at?: string
          voucher_amount?: number
        }
        Relationships: [
          {
            foreignKeyName: "orders_outlet_id_fkey"
            columns: ["outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "orders_staff_id_fkey"
            columns: ["staff_id"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "orders_table_id_fkey"
            columns: ["table_id"]
            isOneToOne: false
            referencedRelation: "outlet_tables"
            referencedColumns: ["id"]
          },
        ]
      }
      outlet_settings: {
        Row: {
          created_at: string
          highlight_specials: boolean
          loyalty_discount_card_restaurant_id: string | null
          loyalty_double_points_enabled: boolean | null
          loyalty_enabled: boolean | null
          loyalty_points_per_pound: number | null
          modifiers_size: number | null
          notes_size: number | null
          order_ticket_copies: number
          outlet_id: string
          print_order_tickets_on_order_away: boolean
          table_number_size: number | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          highlight_specials?: boolean
          loyalty_discount_card_restaurant_id?: string | null
          loyalty_double_points_enabled?: boolean | null
          loyalty_enabled?: boolean | null
          loyalty_points_per_pound?: number | null
          modifiers_size?: number | null
          notes_size?: number | null
          order_ticket_copies?: number
          outlet_id: string
          print_order_tickets_on_order_away?: boolean
          table_number_size?: number | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          highlight_specials?: boolean
          loyalty_discount_card_restaurant_id?: string | null
          loyalty_double_points_enabled?: boolean | null
          loyalty_enabled?: boolean | null
          loyalty_points_per_pound?: number | null
          modifiers_size?: number | null
          notes_size?: number | null
          order_ticket_copies?: number
          outlet_id?: string
          print_order_tickets_on_order_away?: boolean
          table_number_size?: number | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "outlet_settings_outlet_id_fkey"
            columns: ["outlet_id"]
            isOneToOne: true
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
        ]
      }
      outlet_tables: {
        Row: {
          active: boolean
          capacity: number | null
          created_at: string
          id: string
          outlet_id: string
          pos_x: number | null
          pos_y: number | null
          room_name: string
          room_number: number | null
          sort_order: number
          table_number: string
          updated_at: string
        }
        Insert: {
          active?: boolean
          capacity?: number | null
          created_at?: string
          id?: string
          outlet_id: string
          pos_x?: number | null
          pos_y?: number | null
          room_name: string
          room_number?: number | null
          sort_order?: number
          table_number: string
          updated_at?: string
        }
        Update: {
          active?: boolean
          capacity?: number | null
          created_at?: string
          id?: string
          outlet_id?: string
          pos_x?: number | null
          pos_y?: number | null
          room_name?: string
          room_number?: number | null
          sort_order?: number
          table_number?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "outlet_tables_outlet_id_fkey"
            columns: ["outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
        ]
      }
      outlets: {
        Row: {
          active: boolean
          address_line1: string | null
          address_line2: string | null
          code: string | null
          created_at: string
          enable_service_charge: boolean
          id: string
          inventory_mode: string
          name: string
          order_ticket_copies: number
          phone: string | null
          postcode: string | null
          print_order_tickets_on_order_away: boolean
          receipt_codepage: string
          receipt_font_size: number
          receipt_footer_text: string | null
          receipt_header_text: string | null
          receipt_large_total_text: boolean
          receipt_line_spacing: number
          receipt_logo_url: string | null
          receipt_show_logo: boolean
          receipt_show_promotions: boolean
          receipt_show_service_charge: boolean
          receipt_show_vat_breakdown: boolean
          receipt_use_compact_layout: boolean
          service_charge_percent: number
          settings: Json | null
          town: string | null
        }
        Insert: {
          active?: boolean
          address_line1?: string | null
          address_line2?: string | null
          code?: string | null
          created_at?: string
          enable_service_charge?: boolean
          id?: string
          inventory_mode?: string
          name: string
          order_ticket_copies?: number
          phone?: string | null
          postcode?: string | null
          print_order_tickets_on_order_away?: boolean
          receipt_codepage?: string
          receipt_font_size?: number
          receipt_footer_text?: string | null
          receipt_header_text?: string | null
          receipt_large_total_text?: boolean
          receipt_line_spacing?: number
          receipt_logo_url?: string | null
          receipt_show_logo?: boolean
          receipt_show_promotions?: boolean
          receipt_show_service_charge?: boolean
          receipt_show_vat_breakdown?: boolean
          receipt_use_compact_layout?: boolean
          service_charge_percent?: number
          settings?: Json | null
          town?: string | null
        }
        Update: {
          active?: boolean
          address_line1?: string | null
          address_line2?: string | null
          code?: string | null
          created_at?: string
          enable_service_charge?: boolean
          id?: string
          inventory_mode?: string
          name?: string
          order_ticket_copies?: number
          phone?: string | null
          postcode?: string | null
          print_order_tickets_on_order_away?: boolean
          receipt_codepage?: string
          receipt_font_size?: number
          receipt_footer_text?: string | null
          receipt_header_text?: string | null
          receipt_large_total_text?: boolean
          receipt_line_spacing?: number
          receipt_logo_url?: string | null
          receipt_show_logo?: boolean
          receipt_show_promotions?: boolean
          receipt_show_service_charge?: boolean
          receipt_show_vat_breakdown?: boolean
          receipt_use_compact_layout?: boolean
          service_charge_percent?: number
          settings?: Json | null
          town?: string | null
        }
        Relationships: []
      }
      packaged_deal_components: {
        Row: {
          component_name: string
          created_at: string | null
          id: string
          packaged_deal_id: string
          product_ids: string[]
          product_quantities: Json | null
          quantity: number
          updated_at: string | null
        }
        Insert: {
          component_name: string
          created_at?: string | null
          id?: string
          packaged_deal_id: string
          product_ids?: string[]
          product_quantities?: Json | null
          quantity: number
          updated_at?: string | null
        }
        Update: {
          component_name?: string
          created_at?: string | null
          id?: string
          packaged_deal_id?: string
          product_ids?: string[]
          product_quantities?: Json | null
          quantity?: number
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "packaged_deal_components_packaged_deal_id_fkey"
            columns: ["packaged_deal_id"]
            isOneToOne: false
            referencedRelation: "packaged_deals"
            referencedColumns: ["id"]
          },
        ]
      }
      packaged_deals: {
        Row: {
          active: boolean | null
          available_days: number[] | null
          components: Json
          created_at: string | null
          description: string | null
          end_date: string | null
          end_time: string | null
          id: string
          name: string
          outlet_id: string
          price: number
          start_date: string | null
          start_time: string | null
          updated_at: string | null
        }
        Insert: {
          active?: boolean | null
          available_days?: number[] | null
          components: Json
          created_at?: string | null
          description?: string | null
          end_date?: string | null
          end_time?: string | null
          id?: string
          name: string
          outlet_id: string
          price: number
          start_date?: string | null
          start_time?: string | null
          updated_at?: string | null
        }
        Update: {
          active?: boolean | null
          available_days?: number[] | null
          components?: Json
          created_at?: string | null
          description?: string | null
          end_date?: string | null
          end_time?: string | null
          id?: string
          name?: string
          outlet_id?: string
          price?: number
          start_date?: string | null
          start_time?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "packaged_deals_outlet_id_fkey"
            columns: ["outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
        ]
      }
      payment_methods: {
        Row: {
          code: string | null
          created_at: string
          enabled: boolean
          id: string
          include_in_cashup: boolean
          name: string
          outlet_id: string
          sort_order: number
        }
        Insert: {
          code?: string | null
          created_at?: string
          enabled?: boolean
          id?: string
          include_in_cashup?: boolean
          name: string
          outlet_id: string
          sort_order?: number
        }
        Update: {
          code?: string | null
          created_at?: string
          enabled?: boolean
          id?: string
          include_in_cashup?: boolean
          name?: string
          outlet_id?: string
          sort_order?: number
        }
        Relationships: [
          {
            foreignKeyName: "payment_methods_outlet_id_fkey"
            columns: ["outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
        ]
      }
      print_jobs: {
        Row: {
          attempts: number | null
          copies: number | null
          created_at: string | null
          id: string
          last_error: string | null
          order_id: string
          outlet_id: string
          payload_base64: string
          printed_at: string | null
          printer_id: string
          source_device_id: string
          status: string
          target_device_id: string
          updated_at: string | null
        }
        Insert: {
          attempts?: number | null
          copies?: number | null
          created_at?: string | null
          id?: string
          last_error?: string | null
          order_id: string
          outlet_id: string
          payload_base64: string
          printed_at?: string | null
          printer_id: string
          source_device_id: string
          status?: string
          target_device_id: string
          updated_at?: string | null
        }
        Update: {
          attempts?: number | null
          copies?: number | null
          created_at?: string | null
          id?: string
          last_error?: string | null
          order_id?: string
          outlet_id?: string
          payload_base64?: string
          printed_at?: string | null
          printer_id?: string
          source_device_id?: string
          status?: string
          target_device_id?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "print_jobs_outlet_id_fkey"
            columns: ["outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "print_jobs_printer_id_fkey"
            columns: ["printer_id"]
            isOneToOne: false
            referencedRelation: "printers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "print_jobs_source_device_id_fkey"
            columns: ["source_device_id"]
            isOneToOne: false
            referencedRelation: "devices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "print_jobs_target_device_id_fkey"
            columns: ["target_device_id"]
            isOneToOne: false
            referencedRelation: "devices"
            referencedColumns: ["id"]
          },
        ]
      }
      printers: {
        Row: {
          active: boolean
          connection_type: string
          created_at: string
          hardware_address: string | null
          hardware_name: string | null
          hardware_product_id: string | null
          hardware_vendor_id: string | null
          id: string
          ip_address: string | null
          is_default_receipt: boolean
          name: string
          outlet_id: string
          paper_size: string
          port: number | null
          type: string
        }
        Insert: {
          active?: boolean
          connection_type: string
          created_at?: string
          hardware_address?: string | null
          hardware_name?: string | null
          hardware_product_id?: string | null
          hardware_vendor_id?: string | null
          id?: string
          ip_address?: string | null
          is_default_receipt?: boolean
          name: string
          outlet_id: string
          paper_size?: string
          port?: number | null
          type: string
        }
        Update: {
          active?: boolean
          connection_type?: string
          created_at?: string
          hardware_address?: string | null
          hardware_name?: string | null
          hardware_product_id?: string | null
          hardware_vendor_id?: string | null
          id?: string
          ip_address?: string | null
          is_default_receipt?: boolean
          name?: string
          outlet_id?: string
          paper_size?: string
          port?: number | null
          type?: string
        }
        Relationships: [
          {
            foreignKeyName: "printers_outlet_id_fkey"
            columns: ["outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
        ]
      }
      processed_order_ops: {
        Row: {
          created_at: string
          device_id: string
          op_id: string
          op_type: string
          order_id: string
          processed_at: string
        }
        Insert: {
          created_at?: string
          device_id: string
          op_id: string
          op_type: string
          order_id: string
          processed_at?: string
        }
        Update: {
          created_at?: string
          device_id?: string
          op_id?: string
          op_type?: string
          order_id?: string
          processed_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "processed_order_ops_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
        ]
      }
      product_modifier_groups: {
        Row: {
          active: boolean
          created_at: string
          group_id: string
          id: string
          max_select_override: number | null
          min_select_override: number | null
          outlet_id: string
          product_id: string
          required_override: boolean | null
          sort_order: number
        }
        Insert: {
          active?: boolean
          created_at?: string
          group_id: string
          id?: string
          max_select_override?: number | null
          min_select_override?: number | null
          outlet_id: string
          product_id: string
          required_override?: boolean | null
          sort_order?: number
        }
        Update: {
          active?: boolean
          created_at?: string
          group_id?: string
          id?: string
          max_select_override?: number | null
          min_select_override?: number | null
          outlet_id?: string
          product_id?: string
          required_override?: boolean | null
          sort_order?: number
        }
        Relationships: [
          {
            foreignKeyName: "product_modifier_groups_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "modifier_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_modifier_groups_outlet_id_fkey"
            columns: ["outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_modifier_groups_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      product_recipe_components: {
        Row: {
          created_at: string
          id: string
          inventory_item_id: string
          quantity_per_unit: number
          recipe_id: string
          wastage_factor: number | null
        }
        Insert: {
          created_at?: string
          id?: string
          inventory_item_id: string
          quantity_per_unit: number
          recipe_id: string
          wastage_factor?: number | null
        }
        Update: {
          created_at?: string
          id?: string
          inventory_item_id?: string
          quantity_per_unit?: number
          recipe_id?: string
          wastage_factor?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "product_recipe_components_inventory_item_id_fkey"
            columns: ["inventory_item_id"]
            isOneToOne: false
            referencedRelation: "inventory_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_recipe_components_recipe_id_fkey"
            columns: ["recipe_id"]
            isOneToOne: false
            referencedRelation: "product_recipes"
            referencedColumns: ["id"]
          },
        ]
      }
      product_recipes: {
        Row: {
          created_at: string
          id: string
          is_active: boolean
          name: string | null
          outlet_id: string
          product_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          is_active?: boolean
          name?: string | null
          outlet_id: string
          product_id: string
        }
        Update: {
          created_at?: string
          id?: string
          is_active?: boolean
          name?: string | null
          outlet_id?: string
          product_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "product_recipes_outlet_id_fkey"
            columns: ["outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_recipes_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      products: {
        Row: {
          active: boolean
          auto_hide_when_out_of_stock: boolean
          category_id: string | null
          course: string | null
          created_at: string
          id: string
          is_carvery: boolean
          linked_inventory_item_id: string | null
          name: string
          outlet_id: string
          plu: string | null
          price: number
          printer_id: string | null
          sort_order: number
          stock_alerts_enabled: boolean
          stock_max_level: number | null
          stock_min_level: number | null
          tax_rate_id: string | null
          track_stock: boolean
        }
        Insert: {
          active?: boolean
          auto_hide_when_out_of_stock?: boolean
          category_id?: string | null
          course?: string | null
          created_at?: string
          id?: string
          is_carvery?: boolean
          linked_inventory_item_id?: string | null
          name: string
          outlet_id: string
          plu?: string | null
          price?: number
          printer_id?: string | null
          sort_order?: number
          stock_alerts_enabled?: boolean
          stock_max_level?: number | null
          stock_min_level?: number | null
          tax_rate_id?: string | null
          track_stock?: boolean
        }
        Update: {
          active?: boolean
          auto_hide_when_out_of_stock?: boolean
          category_id?: string | null
          course?: string | null
          created_at?: string
          id?: string
          is_carvery?: boolean
          linked_inventory_item_id?: string | null
          name?: string
          outlet_id?: string
          plu?: string | null
          price?: number
          printer_id?: string | null
          sort_order?: number
          stock_alerts_enabled?: boolean
          stock_max_level?: number | null
          stock_min_level?: number | null
          tax_rate_id?: string | null
          track_stock?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "products_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "products_linked_inventory_item_id_fkey"
            columns: ["linked_inventory_item_id"]
            isOneToOne: false
            referencedRelation: "inventory_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "products_outlet_id_fkey"
            columns: ["outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "products_printer_id_fkey"
            columns: ["printer_id"]
            isOneToOne: false
            referencedRelation: "printers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "products_tax_rate_id_fkey"
            columns: ["tax_rate_id"]
            isOneToOne: false
            referencedRelation: "tax_rates"
            referencedColumns: ["id"]
          },
        ]
      }
      promotion_categories: {
        Row: {
          category_id: string
          id: string
          promotion_id: string
        }
        Insert: {
          category_id: string
          id?: string
          promotion_id: string
        }
        Update: {
          category_id?: string
          id?: string
          promotion_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "promotion_categories_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "promotion_categories_promotion_id_fkey"
            columns: ["promotion_id"]
            isOneToOne: false
            referencedRelation: "promotions"
            referencedColumns: ["id"]
          },
        ]
      }
      promotion_components: {
        Row: {
          category_id: string
          created_at: string | null
          display_order: number | null
          id: string
          promotion_id: string
          quantity: number
        }
        Insert: {
          category_id: string
          created_at?: string | null
          display_order?: number | null
          id?: string
          promotion_id: string
          quantity: number
        }
        Update: {
          category_id?: string
          created_at?: string | null
          display_order?: number | null
          id?: string
          promotion_id?: string
          quantity?: number
        }
        Relationships: [
          {
            foreignKeyName: "promotion_components_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "promotion_components_promotion_id_fkey"
            columns: ["promotion_id"]
            isOneToOne: false
            referencedRelation: "promotions"
            referencedColumns: ["id"]
          },
        ]
      }
      promotion_products: {
        Row: {
          id: string
          product_id: string
          promotion_id: string
        }
        Insert: {
          id?: string
          product_id: string
          promotion_id: string
        }
        Update: {
          id?: string
          product_id?: string
          promotion_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "promotion_products_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "promotion_products_promotion_id_fkey"
            columns: ["promotion_id"]
            isOneToOne: false
            referencedRelation: "promotions"
            referencedColumns: ["id"]
          },
        ]
      }
      promotions: {
        Row: {
          active: boolean
          created_at: string
          days_of_week: number[] | null
          description: string | null
          discount_type: string
          discount_value: number | null
          end_date: string | null
          end_time: string | null
          id: string
          name: string
          outlet_id: string
          scope: string
          start_date: string | null
          start_time: string | null
          updated_at: string
          x_qty: number | null
          y_qty: number | null
        }
        Insert: {
          active?: boolean
          created_at?: string
          days_of_week?: number[] | null
          description?: string | null
          discount_type: string
          discount_value?: number | null
          end_date?: string | null
          end_time?: string | null
          id?: string
          name: string
          outlet_id: string
          scope?: string
          start_date?: string | null
          start_time?: string | null
          updated_at?: string
          x_qty?: number | null
          y_qty?: number | null
        }
        Update: {
          active?: boolean
          created_at?: string
          days_of_week?: number[] | null
          description?: string | null
          discount_type?: string
          discount_value?: number | null
          end_date?: string | null
          end_time?: string | null
          id?: string
          name?: string
          outlet_id?: string
          scope?: string
          start_date?: string | null
          start_time?: string | null
          updated_at?: string
          x_qty?: number | null
          y_qty?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "promotions_outlet_id_fkey"
            columns: ["outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
        ]
      }
      refund_transactions: {
        Row: {
          amount_paid: number
          created_at: string
          id: string
          meta: Json | null
          order_id: string
          outlet_id: string
          staff_id: string | null
          staff_name: string | null
        }
        Insert: {
          amount_paid: number
          created_at?: string
          id?: string
          meta?: Json | null
          order_id: string
          outlet_id: string
          staff_id?: string | null
          staff_name?: string | null
        }
        Update: {
          amount_paid?: number
          created_at?: string
          id?: string
          meta?: Json | null
          order_id?: string
          outlet_id?: string
          staff_id?: string | null
          staff_name?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "refund_transactions_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "refund_transactions_outlet_id_fkey"
            columns: ["outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "refund_transactions_staff_id_fkey"
            columns: ["staff_id"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
        ]
      }
      roles: {
        Row: {
          created_at: string
          id: string
          is_default: boolean
          level: number
          name: string
          outlet_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          is_default?: boolean
          level?: number
          name: string
          outlet_id: string
        }
        Update: {
          created_at?: string
          id?: string
          is_default?: boolean
          level?: number
          name?: string
          outlet_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "roles_outlet_id_fkey"
            columns: ["outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
        ]
      }
      staff: {
        Row: {
          active: boolean
          created_at: string
          full_name: string
          id: string
          last_login_at: string | null
          outlet_id: string
          pin_code: string
          role_id: string | null
        }
        Insert: {
          active?: boolean
          created_at?: string
          full_name: string
          id?: string
          last_login_at?: string | null
          outlet_id: string
          pin_code: string
          role_id?: string | null
        }
        Update: {
          active?: boolean
          created_at?: string
          full_name?: string
          id?: string
          last_login_at?: string | null
          outlet_id?: string
          pin_code?: string
          role_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "staff_outlet_id_fkey"
            columns: ["outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "staff_role_id_fkey"
            columns: ["role_id"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["id"]
          },
        ]
      }
      staff_outlets: {
        Row: {
          active: boolean
          created_at: string
          id: string
          outlet_id: string
          role_id: string | null
          staff_id: string
        }
        Insert: {
          active?: boolean
          created_at?: string
          id?: string
          outlet_id: string
          role_id?: string | null
          staff_id: string
        }
        Update: {
          active?: boolean
          created_at?: string
          id?: string
          outlet_id?: string
          role_id?: string | null
          staff_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "staff_outlets_outlet_id_fkey"
            columns: ["outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "staff_outlets_role_id_fkey"
            columns: ["role_id"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "staff_outlets_staff_id_fkey"
            columns: ["staff_id"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
        ]
      }
      stock_movement_media: {
        Row: {
          created_at: string
          id: string
          stock_movement_id: string
          storage_path: string
        }
        Insert: {
          created_at?: string
          id?: string
          stock_movement_id: string
          storage_path: string
        }
        Update: {
          created_at?: string
          id?: string
          stock_movement_id?: string
          storage_path?: string
        }
        Relationships: [
          {
            foreignKeyName: "stock_movement_media_stock_movement_id_fkey"
            columns: ["stock_movement_id"]
            isOneToOne: false
            referencedRelation: "stock_movements"
            referencedColumns: ["id"]
          },
        ]
      }
      stock_movements: {
        Row: {
          change_qty: number
          created_at: string
          created_by_staff_id: string | null
          id: string
          inventory_item_id: string
          note: string | null
          outlet_id: string
          reason: string
        }
        Insert: {
          change_qty: number
          created_at?: string
          created_by_staff_id?: string | null
          id?: string
          inventory_item_id: string
          note?: string | null
          outlet_id: string
          reason: string
        }
        Update: {
          change_qty?: number
          created_at?: string
          created_by_staff_id?: string | null
          id?: string
          inventory_item_id?: string
          note?: string | null
          outlet_id?: string
          reason?: string
        }
        Relationships: [
          {
            foreignKeyName: "stock_movements_created_by_staff_id_fkey"
            columns: ["created_by_staff_id"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_movements_inventory_item_id_fkey"
            columns: ["inventory_item_id"]
            isOneToOne: false
            referencedRelation: "inventory_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_movements_outlet_id_fkey"
            columns: ["outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
        ]
      }
      stock_transfer_lines: {
        Row: {
          created_at: string
          from_inventory_item_id: string
          id: string
          qty: number
          to_inventory_item_id: string | null
          transfer_id: string
        }
        Insert: {
          created_at?: string
          from_inventory_item_id: string
          id?: string
          qty: number
          to_inventory_item_id?: string | null
          transfer_id: string
        }
        Update: {
          created_at?: string
          from_inventory_item_id?: string
          id?: string
          qty?: number
          to_inventory_item_id?: string | null
          transfer_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "stock_transfer_lines_from_inventory_item_id_fkey"
            columns: ["from_inventory_item_id"]
            isOneToOne: false
            referencedRelation: "inventory_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_transfer_lines_to_inventory_item_id_fkey"
            columns: ["to_inventory_item_id"]
            isOneToOne: false
            referencedRelation: "inventory_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_transfer_lines_transfer_id_fkey"
            columns: ["transfer_id"]
            isOneToOne: false
            referencedRelation: "stock_transfers"
            referencedColumns: ["id"]
          },
        ]
      }
      stock_transfers: {
        Row: {
          created_at: string
          created_by_staff_id: string | null
          from_outlet_id: string
          id: string
          note: string | null
          received_at: string | null
          status: string
          submitted_at: string | null
          to_outlet_id: string
        }
        Insert: {
          created_at?: string
          created_by_staff_id?: string | null
          from_outlet_id: string
          id?: string
          note?: string | null
          received_at?: string | null
          status?: string
          submitted_at?: string | null
          to_outlet_id: string
        }
        Update: {
          created_at?: string
          created_by_staff_id?: string | null
          from_outlet_id?: string
          id?: string
          note?: string | null
          received_at?: string | null
          status?: string
          submitted_at?: string | null
          to_outlet_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "stock_transfers_created_by_staff_id_fkey"
            columns: ["created_by_staff_id"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_transfers_from_outlet_id_fkey"
            columns: ["from_outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_transfers_to_outlet_id_fkey"
            columns: ["to_outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
        ]
      }
      supplier_invoice_lines: {
        Row: {
          barcode: string | null
          created_at: string
          description: string
          id: string
          inventory_item_id: string | null
          invoice_id: string
          line_total: number | null
          qty: number
          unit_cost: number | null
        }
        Insert: {
          barcode?: string | null
          created_at?: string
          description: string
          id?: string
          inventory_item_id?: string | null
          invoice_id: string
          line_total?: number | null
          qty: number
          unit_cost?: number | null
        }
        Update: {
          barcode?: string | null
          created_at?: string
          description?: string
          id?: string
          inventory_item_id?: string | null
          invoice_id?: string
          line_total?: number | null
          qty?: number
          unit_cost?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "supplier_invoice_lines_inventory_item_id_fkey"
            columns: ["inventory_item_id"]
            isOneToOne: false
            referencedRelation: "inventory_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_invoice_lines_invoice_id_fkey"
            columns: ["invoice_id"]
            isOneToOne: false
            referencedRelation: "supplier_invoices"
            referencedColumns: ["id"]
          },
        ]
      }
      supplier_invoices: {
        Row: {
          created_at: string
          id: string
          invoice_date: string | null
          invoice_number: string | null
          outlet_id: string
          storage_path: string | null
          supplier_id: string | null
          total: number | null
          uploaded_by_staff_id: string | null
        }
        Insert: {
          created_at?: string
          id?: string
          invoice_date?: string | null
          invoice_number?: string | null
          outlet_id: string
          storage_path?: string | null
          supplier_id?: string | null
          total?: number | null
          uploaded_by_staff_id?: string | null
        }
        Update: {
          created_at?: string
          id?: string
          invoice_date?: string | null
          invoice_number?: string | null
          outlet_id?: string
          storage_path?: string | null
          supplier_id?: string | null
          total?: number | null
          uploaded_by_staff_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "supplier_invoices_outlet_id_fkey"
            columns: ["outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_invoices_supplier_id_fkey"
            columns: ["supplier_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_invoices_uploaded_by_staff_id_fkey"
            columns: ["uploaded_by_staff_id"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
        ]
      }
      suppliers: {
        Row: {
          created_at: string
          email: string | null
          id: string
          name: string
          outlet_id: string
          phone: string | null
        }
        Insert: {
          created_at?: string
          email?: string | null
          id?: string
          name: string
          outlet_id: string
          phone?: string | null
        }
        Update: {
          created_at?: string
          email?: string | null
          id?: string
          name?: string
          outlet_id?: string
          phone?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "suppliers_outlet_id_fkey"
            columns: ["outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
        ]
      }
      sync_processed_ops: {
        Row: {
          client_op_id: string
          created_at: string
          device_id: string
          op_table: string | null
          op_type: string | null
          outlet_id: string
        }
        Insert: {
          client_op_id: string
          created_at?: string
          device_id: string
          op_table?: string | null
          op_type?: string | null
          outlet_id: string
        }
        Update: {
          client_op_id?: string
          created_at?: string
          device_id?: string
          op_table?: string | null
          op_type?: string | null
          outlet_id?: string
        }
        Relationships: []
      }
      table_sessions: {
        Row: {
          connection_status: string | null
          created_at: string
          device_id: string | null
          id: string
          is_active: boolean
          last_heartbeat_at: string
          last_online_at: string | null
          order_id: string
          outlet_id: string
          session_started_at: string
          staff_id: string | null
          staff_name: string
          table_id: string | null
          updated_at: string
        }
        Insert: {
          connection_status?: string | null
          created_at?: string
          device_id?: string | null
          id?: string
          is_active?: boolean
          last_heartbeat_at?: string
          last_online_at?: string | null
          order_id: string
          outlet_id: string
          session_started_at?: string
          staff_id?: string | null
          staff_name: string
          table_id?: string | null
          updated_at?: string
        }
        Update: {
          connection_status?: string | null
          created_at?: string
          device_id?: string | null
          id?: string
          is_active?: boolean
          last_heartbeat_at?: string
          last_online_at?: string | null
          order_id?: string
          outlet_id?: string
          session_started_at?: string
          staff_id?: string | null
          staff_name?: string
          table_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "table_sessions_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "table_sessions_outlet_id_fkey"
            columns: ["outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "table_sessions_staff_id_fkey"
            columns: ["staff_id"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "table_sessions_table_id_fkey"
            columns: ["table_id"]
            isOneToOne: false
            referencedRelation: "outlet_tables"
            referencedColumns: ["id"]
          },
        ]
      }
      tax_rates: {
        Row: {
          created_at: string
          id: string
          is_default: boolean
          name: string
          outlet_id: string | null
          rate: number
        }
        Insert: {
          created_at?: string
          id?: string
          is_default?: boolean
          name: string
          outlet_id?: string | null
          rate: number
        }
        Update: {
          created_at?: string
          id?: string
          is_default?: boolean
          name?: string
          outlet_id?: string | null
          rate?: number
        }
        Relationships: [
          {
            foreignKeyName: "tax_rates_outlet_id_fkey"
            columns: ["outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
        ]
      }
      till_adjustments: {
        Row: {
          adjustment_type: string
          amount_pennies: number
          created_at: string | null
          id: string
          notes: string | null
          outlet_id: string
          reason: string
          staff_id: string
          timestamp: string
          updated_at: string | null
        }
        Insert: {
          adjustment_type: string
          amount_pennies: number
          created_at?: string | null
          id?: string
          notes?: string | null
          outlet_id: string
          reason: string
          staff_id: string
          timestamp?: string
          updated_at?: string | null
        }
        Update: {
          adjustment_type?: string
          amount_pennies?: number
          created_at?: string | null
          id?: string
          notes?: string | null
          outlet_id?: string
          reason?: string
          staff_id?: string
          timestamp?: string
          updated_at?: string | null
        }
        Relationships: []
      }
      trading_days: {
        Row: {
          carry_forward_cash: number | null
          cash_variance: number | null
          closed_at: string | null
          closed_by_staff_id: string | null
          closing_cash_counted: number | null
          id: string
          is_carry_forward: boolean | null
          opened_at: string
          opened_by_staff_id: string
          opening_float_amount: number
          opening_float_source: string
          outlet_id: string
          total_card_sales: number | null
          total_cash_sales: number | null
          total_sales: number | null
          trading_date: string
        }
        Insert: {
          carry_forward_cash?: number | null
          cash_variance?: number | null
          closed_at?: string | null
          closed_by_staff_id?: string | null
          closing_cash_counted?: number | null
          id?: string
          is_carry_forward?: boolean | null
          opened_at?: string
          opened_by_staff_id: string
          opening_float_amount?: number
          opening_float_source: string
          outlet_id: string
          total_card_sales?: number | null
          total_cash_sales?: number | null
          total_sales?: number | null
          trading_date: string
        }
        Update: {
          carry_forward_cash?: number | null
          cash_variance?: number | null
          closed_at?: string | null
          closed_by_staff_id?: string | null
          closing_cash_counted?: number | null
          id?: string
          is_carry_forward?: boolean | null
          opened_at?: string
          opened_by_staff_id?: string
          opening_float_amount?: number
          opening_float_source?: string
          outlet_id?: string
          total_card_sales?: number | null
          total_cash_sales?: number | null
          total_sales?: number | null
          trading_date?: string
        }
        Relationships: [
          {
            foreignKeyName: "trading_days_closed_by_staff_id_fkey"
            columns: ["closed_by_staff_id"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "trading_days_opened_by_staff_id_fkey"
            columns: ["opened_by_staff_id"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "trading_days_outlet_id_fkey"
            columns: ["outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
        ]
      }
      transactions: {
        Row: {
          amount_paid: number
          change_given: number
          created_at: string
          discount_amount: number
          id: string
          loyalty_redeemed: number
          meta: Json | null
          order_id: string
          outlet_id: string
          payment_method: string
          payment_ref: string | null
          payment_status: string
          service_charge: number
          staff_id: string | null
          subtotal: number
          tax_amount: number
          till_id: string | null
          total_due: number
          voucher_amount: number
        }
        Insert: {
          amount_paid: number
          change_given?: number
          created_at?: string
          discount_amount?: number
          id?: string
          loyalty_redeemed?: number
          meta?: Json | null
          order_id: string
          outlet_id: string
          payment_method: string
          payment_ref?: string | null
          payment_status?: string
          service_charge?: number
          staff_id?: string | null
          subtotal: number
          tax_amount: number
          till_id?: string | null
          total_due: number
          voucher_amount?: number
        }
        Update: {
          amount_paid?: number
          change_given?: number
          created_at?: string
          discount_amount?: number
          id?: string
          loyalty_redeemed?: number
          meta?: Json | null
          order_id?: string
          outlet_id?: string
          payment_method?: string
          payment_ref?: string | null
          payment_status?: string
          service_charge?: number
          staff_id?: string | null
          subtotal?: number
          tax_amount?: number
          till_id?: string | null
          total_due?: number
          voucher_amount?: number
        }
        Relationships: [
          {
            foreignKeyName: "transactions_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "transactions_outlet_id_fkey"
            columns: ["outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "transactions_staff_id_fkey"
            columns: ["staff_id"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      v_active_conflicts: {
        Row: {
          conflict_type: string | null
          detected_at: string | null
          device_id: string | null
          id: string | null
          minutes_pending: number | null
          order_id: string | null
          order_status: string | null
          outlet_id: string | null
          severity: string | null
        }
        Relationships: [
          {
            foreignKeyName: "order_conflicts_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "orders_outlet_id_fkey"
            columns: ["outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Functions: {
      cleanup_old_print_jobs: { Args: never; Returns: undefined }
      compute_order_hash: { Args: { p_order_id: string }; Returns: string }
      get_table_columns: {
        Args: { table_name_param: string }
        Returns: {
          column_name: string
          data_type: string
        }[]
      }
      validate_operation_payload: {
        Args: { p_op_type: string; p_payload: Json }
        Returns: boolean
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {},
  },
} as const
