// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)

// app/javascript/controllers/index.js に追加
import DementiaCheckerController from "./dementia_checker_controller"
application.register("dementia-checker", DementiaCheckerController)