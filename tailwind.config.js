const defaultTheme = require('tailwindcss/defaultTheme');

module.exports = {
  experimental: {
    applyComplexClasses: true,
    defaultLineHeights: true,
  },
  future: {
    purgeLayersByDefault: true,
    removeDeprecatedGapUtilities: true,
  },
  plugins: [require("@tailwindcss/typography"), require("@tailwindcss/ui")],
  purge: ["cms/templates/**/*.twig", "src/js/**/*.js"],
  theme: {
    container: {
      center: true,
      padding: defaultTheme.spacing.s4,
    },
    extend: {
      colors: {
        "brand-black": "#000",
      },
      fontFamily: {
        sans: ["Inter var", ...defaultTheme.fontFamily.sans],
      },
    },
  },
};
