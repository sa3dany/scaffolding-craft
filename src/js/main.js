import { trackErrors } from "./utils.js";
import * as Cookies from "tiny-cookie";

trackErrors();
window.Cookies = Cookies;
