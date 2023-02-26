import { NextFunction, Request, Response } from 'express';

class IndexController {
  public index = (req: Request, res: Response, next: NextFunction): void => {
    try {
      res.json({
        status: 200,
        message: 'success',
      });
    } catch (error) {
      next(error);
    }
  };
}

export default IndexController;
