module ApplicationHelper
  ACTION_PALETTE = {
    approve: "bg-blue-600 hover:bg-blue-500 text-white",
    ship:    "bg-indigo-600 hover:bg-indigo-500 text-white",
    deliver: "bg-emerald-600 hover:bg-emerald-500 text-white",
    cancel:  "bg-rose-600 hover:bg-rose-500 text-white"
  }.freeze

  def action_button_classes(event)
    color = ACTION_PALETTE.fetch(event.to_sym, "bg-slate-700 text-white")
    "rounded-md px-3 py-1.5 text-sm font-medium #{color}"
  end
end
