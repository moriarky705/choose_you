import { Application } from "@hotwired/stimulus"
import RoomController from "./room_controller"
import NameFormController from "./name_form_controller"
import FlashController from "./flash_controller"

window.Stimulus = Application.start()
Stimulus.register("room", RoomController)
Stimulus.register("name-form", NameFormController)
Stimulus.register("flash", FlashController)
