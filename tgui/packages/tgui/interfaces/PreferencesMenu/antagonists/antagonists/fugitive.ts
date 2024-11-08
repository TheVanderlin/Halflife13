import { Antagonist, Category } from "../base";
import { multiline } from "common/string";

export const FUGITIVE_MECHANICAL_DESCRIPTION
   = multiline`
      Avoid being caught by the police or overwatch.
   `;


const Fugitive: Antagonist = {
  key: "fugitive",
  name: "Fugitive",
  description: [
    multiline`
      Freedom. You gained it somehow, but you're not about to give it up.
      You're being pursued, and the only friends are those that might be with you.
      It's unclear who they'll send after you, but a bounty'll be claimed, whether you're dead or alive.
    `,
    FUGITIVE_MECHANICAL_DESCRIPTION,
  ],
  category: Category.Midround,
};

export default Fugitive;
