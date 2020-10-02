import { trackErrors } from "./utils.js";
import * as Cookies from "tiny-cookie";
import 'alpinejs'

trackErrors();
window.Cookies = Cookies;
