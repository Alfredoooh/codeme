const AppLogo = ({ size = 32 }) => (
  <svg
    width={size}
    height={size}
    viewBox="0 0 32 32"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
  >
    <rect width="32" height="32" rx="8" fill="#007aff" />
    <path d="M9 10h9a4 4 0 0 1 0 8H9V10Z" fill="#fff" opacity=".9" />
    <path
      d="M9 18h10a5 5 0 0 1 0 10"
      stroke="#fff"
      strokeWidth="2"
      strokeLinecap="round"
      fill="none"
      opacity=".6"
    />
    <circle cx="9" cy="24" r="2" fill="#fff" opacity=".6" />
  </svg>
);

export default AppLogo;