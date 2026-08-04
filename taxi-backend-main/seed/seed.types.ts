export type Seed = {
  name: string;
  run: () => Promise<void>;
};
