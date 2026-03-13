# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_03_13_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_stat_statements"

  create_table "ai_tasks", force: :cascade do |t|
    t.json "payload"
    t.string "state", default: "pending"
    t.json "result"
  end

  create_table "chat_messages", force: :cascade do |t|
    t.integer "design_id"
    t.string "author"
    t.text "message"
    t.string "state", default: "completed"
    t.integer "iteration_id"
  end

  create_table "component_sets", force: :cascade do |t|
    t.bigint "figma_file_id", null: false
    t.string "node_id", null: false
    t.string "name"
    t.text "description"
    t.string "figma_file_key"
    t.string "figma_file_name"
    t.jsonb "prop_definitions", default: {}
    t.boolean "is_root", default: false, null: false
    t.jsonb "slots", default: []
    t.string "status", default: "pending"
    t.text "error_message"
    t.string "component_key"
    t.index ["figma_file_id", "node_id"], name: "index_component_sets_on_figma_file_id_and_node_id", unique: true
    t.index ["figma_file_id"], name: "index_component_sets_on_figma_file_id"
    t.index ["node_id"], name: "index_component_sets_on_node_id"
  end

  create_table "component_variants", force: :cascade do |t|
    t.bigint "component_set_id", null: false
    t.string "node_id", null: false
    t.string "name"
    t.jsonb "figma_json", default: {}
    t.text "react_code"
    t.text "react_code_compiled"
    t.boolean "is_default", default: false
    t.text "html_code"
    t.text "css_code"
    t.float "match_percent"
    t.string "diff_image_path"
    t.string "figma_screenshot_path"
    t.string "react_screenshot_path"
    t.string "component_key"
    t.index ["component_set_id", "node_id"], name: "index_component_variants_on_component_set_id_and_node_id", unique: true
    t.index ["component_set_id"], name: "index_component_variants_on_component_set_id"
    t.index ["node_id"], name: "index_component_variants_on_node_id"
  end

  create_table "components", force: :cascade do |t|
    t.integer "figma_file_id"
    t.string "kind"
    t.string "node_id", null: false
    t.string "name", null: false
    t.text "description"
    t.jsonb "prop_definitions", default: {}, null: false
    t.jsonb "deps", default: [], null: false
    t.text "react_code"
    t.jsonb "schema"
    t.datetime "updated_at", precision: nil
    t.jsonb "figma_json"
    t.string "figma_file_key"
    t.string "component_set_id"
    t.string "component_set_name"
    t.string "figma_file_name"
    t.text "react_code_compiled"
    t.text "html_code"
    t.text "css_code"
    t.string "status", default: "pending"
    t.float "match_percent"
    t.text "error_message"
    t.boolean "enabled", default: true
    t.boolean "is_root", default: false, null: false
    t.jsonb "slots", default: []
    t.string "diff_image_path"
    t.string "figma_screenshot_path"
    t.string "react_screenshot_path"
    t.string "source", default: "figma", null: false
    t.jsonb "prop_types", default: {}
    t.string "component_key"
  end

  create_table "design_systems", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "version", default: 1, null: false
    t.string "status", default: "pending"
    t.jsonb "progress", default: {}
    t.boolean "is_public", default: false, null: false
    t.index ["user_id"], name: "index_design_systems_on_user_id"
  end

  create_table "designs", force: :cascade do |t|
    t.string "prompt"
    t.string "name"
    t.string "status", default: "draft", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.bigint "user_id"
    t.bigint "design_system_id"
    t.index ["design_system_id"], name: "index_designs_on_design_system_id"
    t.index ["user_id"], name: "index_designs_on_user_id"
  end

  create_table "exports", force: :cascade do |t|
    t.bigint "design_id", null: false
    t.bigint "iteration_id", null: false
    t.string "format", null: false
    t.string "status", default: "pending", null: false
    t.string "file_path"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["design_id"], name: "index_exports_on_design_id"
    t.index ["iteration_id"], name: "index_exports_on_iteration_id"
  end

  create_table "figma_assets", force: :cascade do |t|
    t.bigint "component_id"
    t.string "node_id", null: false
    t.string "name"
    t.string "asset_type", null: false
    t.text "content"
    t.bigint "component_set_id"
    t.index ["component_id", "node_id"], name: "index_figma_assets_on_component_id_and_node_id", unique: true
    t.index ["component_id"], name: "index_figma_assets_on_component_id"
    t.index ["component_set_id"], name: "index_figma_assets_on_component_set_id"
    t.index ["node_id"], name: "index_figma_assets_on_node_id"
  end

  create_table "figma_files", force: :cascade do |t|
    t.integer "user_id"
    t.string "name"
    t.string "figma_url"
    t.string "figma_file_key"
    t.string "figma_file_name"
    t.string "status", default: "pending"
    t.jsonb "progress", default: {}
    t.integer "version", default: 1, null: false
    t.bigint "design_system_id"
    t.index ["design_system_id"], name: "index_figma_files_on_design_system_id"
    t.index ["user_id", "figma_file_key"], name: "index_figma_files_on_user_id_and_figma_file_key"
    t.index ["user_id"], name: "index_figma_files_on_user_id"
  end

  create_table "image_caches", force: :cascade do |t|
    t.string "query", null: false
    t.text "url", null: false
    t.integer "width"
    t.integer "height"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["query"], name: "index_image_caches_on_query", unique: true
  end

  create_table "iterations", force: :cascade do |t|
    t.integer "design_id"
    t.text "jsx"
    t.integer "render_id"
    t.string "comment"
    t.bigint "design_system_id"
    t.integer "design_system_version"
    t.jsonb "tree"
    t.string "share_code", limit: 6
    t.index ["design_system_id"], name: "index_iterations_on_design_system_id"
    t.index ["share_code"], name: "index_iterations_on_share_code", unique: true
  end

  create_table "renders", force: :cascade do |t|
    t.binary "image"
    t.string "token"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.binary "payload", null: false
    t.datetime "created_at", null: false
    t.bigint "channel_hash", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.binary "key", null: false
    t.binary "value", null: false
    t.datetime "created_at", null: false
    t.bigint "key_hash", null: false
    t.integer "byte_size", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "username"
    t.string "auth0_id"
    t.string "email"
    t.index ["auth0_id"], name: "index_users_on_auth0_id", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "component_sets", "figma_files"
  add_foreign_key "component_variants", "component_sets"
  add_foreign_key "design_systems", "users"
  add_foreign_key "designs", "design_systems"
  add_foreign_key "designs", "users"
  add_foreign_key "exports", "designs"
  add_foreign_key "exports", "iterations"
  add_foreign_key "figma_assets", "component_sets"
  add_foreign_key "figma_assets", "components"
  add_foreign_key "figma_files", "design_systems"
  add_foreign_key "iterations", "design_systems"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
end
